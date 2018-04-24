#!/usr/bin/env perl

use strict;
use warnings;

use Storable;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

my $file = 'data.storable';
my ($task, $action) = @ARGV;

initialise($file) unless -f $file;

my $data = load($file);
print "before: ".Dumper($data);

die "usage: $0 [action] [task]\n" unless $action && $task;
$data = action($data, $task, $action);
print "after: ".Dumper($data);

save($data, $file);

exit;

#############################

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
            ceed_fats => {
                id => 1,
                display_name => "Deed Tats Fet Wood",
                system_name => "deed_tats_fed_wood",
                description => "Fill two b___ from c___ under s___",
                day => "every",
                time => "8pm",
                state => "todo",
            },
        }
        #states => [qw/ todo doing done /],
    );
    store \%data, $file;
}
