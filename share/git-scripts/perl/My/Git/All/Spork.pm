package My::Git::All::Spork;
use warnings;
use strict;
use v5.10.0;

use Moo;

has 'processHash' => (is => 'rw', default => sub { return {}; } );
has 'die'         => (is => 'rw', default => 0);

sub fork {
    my $self = shift;
    my ($start, $done, $data);
    if (scalar @_ == 2 &&
            eval { ref $_[0] eq 'CODE' } &&
            eval { ref $_[1] eq 'CODE' }) {
        ($start, $done) = @_;
    } elsif (scalar @_ == 3 &&
                 eval { ref $_[0] eq 'CODE' } &&
                 eval { ref $_[1] eq 'CODE' }) {
        ($start, $done, $data) = @_;
    } else {
        my (%args) = @_;
        $start = $args{start};
        $done = $args{done};
        $data = $args{data};
    }
    my $pid = fork();
    if (!defined $pid) {
        if ($self->die) {
            die("fork: $!\n");
        }
        return;
    }
    if (!$pid) {
        $start->();
    }
    $self->processHash->{$pid} = {
        done => $done,
        data => $data,
    };
    return $pid;
}

sub wait {
    my ($self) = @_;
    my $processHash = $self->processHash;
    my $pid = wait();
    if ($pid == -1) {      # no child processes
        # This could mean child processes are being
        # automatically reaped.  See perlipc(1).
        if ($self->die) {
            die("unexpected: no child process\n");
        }
        return;
    }
    if (!defined $pid) {
        if ($self->die) {
            die("unexpected: wait returned no child process id\n");
        }
        return;
    }
    my $process = $processHash->{$pid};
    if (!defined $process) {
        # child not spawned via this object.
        if ($self->die) {
            die("unexpected: wait returned pid not managed by this spork\n");
        }
        return;
    }
    delete $processHash->{$pid};
    my $status = $?;
    my $exit     = $status >> 8;
    my $signal   = $status & 127;
    my $coredump = $status & 128;
    my $done = $process->{done};
    if ($done && ref $done eq 'CODE') {
        my $data = $process->{data};
        $done->($pid, $status, $exit, $signal, $coredump, $data);
    }
    return ($pid, $process) if wantarray;
    return $pid;
}

sub waitx {
    my ($self) = @_;
    my $processHash = $self->processHash;
    my $numProcs = scalar keys %$processHash;
    my $result = 0;
    for (my $i = 0; $i < $numProcs; $i += 1) {
        my $pid = $self->wait();
        if (defined $pid) {
            $result += 1;
        }
    }
    return $result;
}

sub waitall {
    my ($self) = @_;
    my $processHash = $self->processHash;
    while (scalar keys %$processHash) {
        my $pid = $self->wait();
    }
    return;
}

sub done {
    my ($self, $pid, $sub) = @_;
    my $processHash = $self->processHash;
    my $process = $processHash->{$pid};
    return if !$process;
    $process->{done} = $sub;
}

1;
