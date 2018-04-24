#!/usr/bin/perl

package MyWebServer;
 
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

# setup
Tasks::initialise();
my $data = Tasks::load();

# webserver

#my %dispatch = (
#    '/hello' => \&resp_hello,
#    # ...
#);
 
sub handle_request {
    my $self = shift;
    my $cgi  = shift;
   
    my $path = $cgi->path_info();
    logger("Path = '$path'");
    return web_display($data) if $path =~ m{\d+/?$};

#    my $handler = $dispatch{$path};
    my ($task, $action) = extract($path);

    return error("Invalid request") unless $task && $action;

#    if (ref($handler) eq "CODE") {
#        print "HTTP/1.0 200 OK\r\n";
#        $handler->($cgi);
#
    if (Tasks::exists($data, $task)) {
        $data = Tasks::action($data, $task, $action);
        return web_display($data);
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
    my ($data) = @_;
    print "HTTP/1.0 200 Ok\r\n";
    print $cgi->header,
          $cgi->start_html('Tasks'),
          $cgi->strong('Display'),
          $cgi->br;
          
#          $cgi->p($msg),
    print $cgi->p($_->{display_name} . ' => ' . $_->{state}) foreach $data->{tasks};

    print $cgi->end_html;
    return;
}

sub error {
    my ($msg) = @_;
    print "HTTP/1.0 500 Error\r\n";
    print $cgi->header,
          $cgi->start_html('Error'),
          $cgi->strong('Error'),
          $cgi->br,
          $cgi->p($msg),
          $cgi->end_html;
    return;
}

sub resp_hello {
    my $cgi  = shift;   # CGI.pm object
    return if !ref $cgi;
     
    my $who = $cgi->param('name');
     
    print $cgi->header,
          $cgi->start_html("Hello"),
          $cgi->h1("Hello $who!"),
          $cgi->end_html;
}

sub logger {
    my ($msg) = @_;
    warn "LOGGER: $msg\n";
}

package Tasks;

my $file = 'data.storable';

# Check whether a task exists
sub exists {
    my ($data, $task) = @_;
    return exists $data->{tasks}{$task};
}

# Change state of a task
sub action {
    my ($data, $task, $action) = @_;
    
    return error("expected data") unless $data;
    return error("expected task") unless $task;
    return error("expected action") unless $action;
    
    $data->{tasks}{$task}{state} = $action;
    print "Updated task '$task' to state '$action'\n";
    return $data;
}

# Save new data to disk
sub save {
    my ($data, $file) = @_;
    return error("expected data") unless $data;
    return error("expected file") unless $file;
    
    store $data, $file;
}

# Retrieve data from disk
sub load {
    my ($file) = @_;
    return error("expected file") unless $file;

    my $data = retrieve($file);
    return $data;
}

# Save initial data to disk
sub initialise {
    my ($file) = @_;
    return error("expected file") unless $file;
    return unless -f $file;
    
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
}

sub logger {
    my ($msg) = @_;
    warn "LOGGER: $msg\n";
}

sub error {
    my ($msg) = @_;
    logger($msg);
}

package main;

# start the server on port 8080
my $pid = MyWebServer->new(8080)->background();
print "Use 'kill $pid' to stop server.\n";
