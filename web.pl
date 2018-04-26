#!/usr/bin/perl

{
package Tasks;

use Moose;
use Storable;
use DateTime;

has 'file' => (
   is => 'ro',
   isa => 'Str',
   #default => 'data.storable',
   default => 'data.csv',
);

has 'data' => (
    is => 'rw',
    isa => 'HashRef',
);

has 'datetime' => (
    is => 'ro',
    isa => 'DateTime',
    lazy => 1,
    default => sub {
        return DateTime->now;
    },
);

has 'day' => (
    is => 'rw',
    isa => 'Str',
    default => sub {
        my ($self) = @_;
        return lc($self->datetime->day_abbr);
    },
);

sub BUILD {
    my ($self, $args) = @_;
    $self->init;
    $self->load;
}

# Check whether a task exists
sub task_exists {
    my ($self, $task) = @_;
    my $data = $self->data;
    die error("expected task") unless $task;
    return exists $data->{tasks}{$task};
}

# Change state of a task
sub action {
    my ($self, $task, $action) = @_;
    my $data = $self->data;
    my $file = $self->file;

    die error("expected data") unless $data;
    die error("expected task") unless $task;
    die error("expected action") unless $action;

    $data->{tasks}{$task}{state} = $action;
    $self->data($data);
    $self->save;
    print "Updated task '$task' to state '$action'\n";

    return;
}

# Save new data to disk
sub save {
    my ($self) = @_;
    my $data = $self->data;
    my $file = $self->file;
    die error("expected data") unless $data;
    die error("expected file") unless $file;

    store $data, $file;
}

# Retrieve data from disk
sub load {
    my ($self) = @_;
    use Text::CSV;
    my $csv = Text::CSV->new or die "Cannot use CSV: ".Text::CSV->error_diag;
    open my $fh, "<:encoding(utf8)", $self->file or die $self->file.": $!";
    # Parse CSV into data structure
    # TODO: Use a class for the data instead of a hash
    my $headers = $csv->getline($fh);
    $csv->column_names(@$headers);
    my $data;
    while (my $row = $csv->getline_hr($fh)) {
        my $key = delete($row->{system_name});

        # separate combined fields
        foreach my $field (qw/when states/) {
            $row->{$field} = [ split('/', delete($row->{$field})) ];
        }

        # active or not?
        $row->{active} = (grep { lc($_) eq lc($self->day) } @{ $row->{when} }) ? 1 : 0;

        # define next states
        my $prev;
        my $next_states = {};
        foreach my $entry (@{ $row->{states} }) {
            # make state chains
            my $state1 = $entry; $state1 =~ s/=.+//;
            if (! $prev) { # first state
                $next_states->{start} = $state1;
            }
            else { # subsequent states
                $next_states->{$prev} = $state1;
            }
            $prev = $state1;

            # seperate combined fields
            next if $entry !~ /=/;
            my ($state, $next) = split('=', $entry);
            $next_states->{$state} = "ext:".$next;
        }
        $next_states->{$prev} = 'finish' unless $next_states->{$prev};

        # current state
        $row->{current_state} = $next_states->{start};

        # update states
        $row->{states} = $next_states;

        # populate data
        $data->{tasks}{$key} = $row;
    }
use Data::Dumper;
print "data = ".Dumper($data);
    $csv->eof or $csv->error_diag;
    close $fh;
    $self->data($data);
    return;
}

# Retrieve data from disk
sub load_old {
    my ($self) = @_;
    my $file = $self->file;
    die error("expected file") unless $file;

    my $data = retrieve($file);
    $self->data($data);
    return;
}

# Generate initial data. Run once only.
sub init {
    my ($self) = @_;
    my $file = $self->file;
    die error("expected file") unless $file;
    return if -f $file;

    logger("Re-setting database to initial values");

    my %data = (
        tasks => {
            feed_cats => {
                id => 1,
                display_name => "Feed cats wet food",
                description => "Fill two bowls",
                day => "every",
                'time' => "8pm",
                'state' => "todo",
            },
        }
    );
    store \%data, $file;

    return;
}

# TODO: Add $self
sub logger {
    my ($msg) = @_;
    warn "LOGGER: $msg\n";
    return;
}

sub error {
    my ($msg) = @_;
    logger($msg);
    return;
}

}

#####

{
package MyWebServer;

use strict;
use warnings;

use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

# setup
my $tasks = Tasks->new;

# webserver

sub handle_request {
    my $self = shift;
    my $cgi  = shift;

    my $path = $cgi->path_info();
    logger("Path = '$path'");
    return web_display($cgi, $tasks->data) if $path =~ m{^/$};

    my ($task, $action) = extract_path($path);

    return error($cgi, "Invalid request") unless $task && $action;

    if ($tasks->task_exists($task)) {
        $tasks->action($task, $action);
        return web_display($cgi, $tasks->data);
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
              $cgi->start_html('Not found'),
              $cgi->h1('Not found'),
              $cgi->end_html;
        return;
    }
}

sub extract_path {
    my ($path) = @_;
    my ($task, $action) = $path =~ m{/([^/]+)/([^/]+)$};
    logger("Extracted from $path --> task = '$task', action = '$action'");
    return ($task, $action);
}

sub web_display {
    my ($cgi, $data) = @_;

    print "HTTP/1.0 200 Ok\r\n";
    print $cgi->header,
          $cgi->start_html('Tasks'),
          $cgi->strong('Display'),
          $cgi->br;

    foreach my $key (keys %{ $data->{tasks} }) {
        my $task = $data->{tasks}{$key};
        next unless $task->{active};
        print $cgi->p(
            $task->{display_name}
            . ' => ' .
            $task->{current_state}
        );
    }

    print $cgi->end_html;
    return;
}

sub error {
    my ($cgi, $msg) = @_;
    print "HTTP/1.0 500 Error\r\n";
    print $cgi->header,
          $cgi->start_html('Error'),
          $cgi->strong('Error'),
          $cgi->br,
          $cgi->p($msg),
          $cgi->end_html;
    return;
}

sub logger {
    my ($msg) = @_;
    warn "LOGGER: $msg\n";
    return;
}

}

#####

{
package main;

use strict;
use warnings;

# start the server on port 8080
#my $pid = MyWebServer->new(8080)->background();
my $pid = MyWebServer->new(8080)->run();
print "Use 'kill $pid' to stop server.\n";
}
