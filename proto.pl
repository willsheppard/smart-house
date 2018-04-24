#!/usr/bin/env perl

use strict;
use warnings;

use Storable;

my $file = 'data.storable';
my ($task, $action) = @ARGV;

initialise($file) unless -f $file;

my $data = load($file);
display($data);

die "usage: $0 [task] [action]\n" unless $action && $task;
$data = action($data, $task, $action);
display($data);

save($data, $file);

exit;

#############################

# Show state of tasks
sub display {
    my ($data) = @_;
    print "+------------+--------+\n";
    print "| Task       | Status |\n";
    print "+------------+--------+\n";
    foreach my $task (keys %{ $data->{tasks} }) {
        print "| $task  | ".$data->{tasks}{$task}{state}."   |\n";
    }
    print "+------------+--------+\n";
}

# Change state of a task
sub action {
    my ($data, $task, $action) = @_;
    $data->{tasks}{$task}{state} = $action;
    print "Updated task '$task' to state '$action'\n";
    return $data;
}

# Save new data to disk
sub save {
    my ($data, $file) = @_;
    store $data, $file;
}

# Retrieve data from disk
sub load {
    my ($file) = @_;
    my $data = retrieve($file);
    return $data;
}

# Save initial data to disk
sub initialise {
    my ($file) = @_;
    my %data = (
        tasks => {
            feed_cats => {
                id => 1,
                display_name => "Feed cats wet food",
                description => "Fill two bowls",
                day => "every",
                time => "8pm",
                state => "todo",
            },
        }
    );
    store \%data, $file;
}
