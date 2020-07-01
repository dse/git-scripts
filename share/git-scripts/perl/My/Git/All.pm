package My::Git::All;
use warnings;
use strict;
use v5.10.0;

use String::Unescape;

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    return $self;
}

use lib "$ENV{HOME}/git/dse.d/git-scripts/share/git-scripts/perl";
use My::Git::All::Spork;
use My::Git::All::Util qw(spork);
use My::Git::All::Term qw(isVT);
use Term::ANSIColor qw(color);

sub run {
    my ($self, @arguments) = @_;

    my ($command, $arguments, $directories) = $self->split_arguments(arguments => \@arguments);
    my @directories = @$directories;
    @arguments = @$arguments;

    if (!defined $command) {
        die("No command specified.  Type '$0 --help' for help.\n");
    }
    if ($command eq "test-git-all-porcelain") {
        printf("\$command:     %s\n", $command);
        printf("\@arguments:   %s (%s)\n", scalar @arguments, join " ", @arguments);
        printf("\@directories: %s (%s)\n", scalar @directories, join " ", @directories);
        exit(0);
    }
    if (scalar @directories) {
        foreach my $directory (@directories) {
            if (-d $directory) {
                if ($self->is_in_git_repos(directory => $directory)) {
                    $self->run_git_command_in(directory => $directory,
                                              relative_directory => $directory,
                                              command => $command,
                                              arguments => \@arguments);
                } else {
                    $self->recurse_here(directory => $directory,
                                        command => $command,
                                        arguments => \@arguments);
                }
            } else {
                warn("$directory: not a directory\n");
            }
        }
    } else {
        if ($self->is_in_git_repos()) {
            $self->run_git_command_in(directory => ".",
                                      command => $command,
                                      arguments => \@arguments);
        } else {
            $self->recurse_here(command => $command,
                                arguments => \@arguments);
        }
    }
}

sub split_arguments {
    my ($self, %args) = @_;
    my @arguments = @{$args{arguments}};

    my $three_dashes_index = undef;
  argument:
    for (my $i = 0; $i < @arguments; $i += 1) {
        if ($arguments[$i] eq "---") {
            $three_dashes_index = $i;
            last argument;
        }
    }

    my @directories;
    if (defined $three_dashes_index) {
        @directories = splice(@arguments, $three_dashes_index + 1);
        splice(@arguments, $three_dashes_index);
    }

    my $command = shift(@arguments);

    if (wantarray) {
        return ($command, \@arguments, \@directories);
    } else {
        return {
            command => $command,
            arguments => \@arguments,
            directories => \@directories
        };
    }
}

sub is_in_git_repos {
    my ($self, %args) = @_;
    my $dir = $args{directory};
    my $pid = spork {
        close(\*STDOUT);
        close(\*STDERR);
        if (defined $dir && $dir ne ".") {
            if (!chdir($dir)) {
                die("chdir $dir: $!");
            }
        }
        if (!exec("git", "rev-parse", "--git-dir")) {
            die("exec git: $!");
        }
    };
    if (waitpid($pid, 0) == -1) {
        warn("unexpected: no child process\n");
        return 0;               # failure
    } else {
        if ($?) {
            return 0;           # failure
        } else {
            return 1;           # success
        }
    }
}

use File::Find;
use feature "say";
use Cwd;
use File::Spec;
use File::Basename qw(dirname basename);
use String::ShellQuote;

sub has_io_pty {
    my ($self) = @_;
    return 0 if $self->{no_pty};
    return $self->{has_io_pty} if defined $self->{has_io_pty};
    eval {
        require IO::Pty;
        import IO::Pty qw();
    };
    return $self->{has_io_pty} = $@ ? 0 : 1;
}

sub recurse_here {
    my ($self, %args) = @_;
    my $depth = $args{depth} // 0;
    my $dir = $args{directory} // ".";
    my $command = $args{command};
    my @arguments = @{$args{arguments}};

    if (defined $self->{maxdepth}) {
        if ($depth > $self->{maxdepth}) {
            return;
        }
    }

    my $wanted = sub {
        if (-d $_) {
            if (-d "$_/.git") {
                my @splitdir = File::Spec->splitdir($File::Find::name);
                my $splitdir = scalar @splitdir;
                my $newdepth = $depth + $splitdir - 1;
                if (defined $self->{maxdepth}) {
                    if ($newdepth > $self->{maxdepth}) {
                        $File::Find::prune = 1;
                        return;
                    }
                }
                $self->run_git_command_in(depth => $newdepth,
                                          directory => $File::Find::name,
                                          relative_directory => $_,
                                          command => $command,
                                          arguments => \@arguments);
                $File::Find::prune = 1;
            }
        }
    };
    find({ wanted => $wanted }, $dir);
}

sub stdout {
    my ($self, $line) = @_;
    local $_ = $line;
    s{\R\z}{};
    if ($self->{inline}) {
        if (isVT(1)) {
            print STDOUT color('green');
        }
        print STDOUT $self->{inline_prefix};
        if (isVT(1)) {
            print STDOUT color('reset');
        }
        print STDOUT $self->{inline_separator} if defined $self->{inline_separator};
    } elsif ($self->{indent}) {
        print STDOUT "    ";
    }
    print STDOUT "$_\n";
    STDOUT->flush();
}

sub stderr {
    my ($self, $line) = @_;
    local $_ = $line;
    s{\R\z}{};
    if ($self->{inline}) {
        if (isVT(2)) {
            print STDERR color('green');
        }
        print STDERR $self->{inline_prefix};
        if (isVT(2)) {
            print STDERR color('reset');
        }
        print STDERR $self->{inline_separator} if defined $self->{inline_separator};
    } elsif ($self->{indent}) {
        print STDERR "    ";
    }
    print STDERR "$_\n";
    STDERR->flush();
}

sub run_git_command_in {
    my ($self, %args) = @_;
    my $depth = $args{depth} // 1;
    my $dir = $args{directory} // ".";
    $dir =~ s{^\.\/(?=.)}{};
    my $reldir = $args{relative_directory};
    my $command = $args{command};
    my @arguments = @{$args{arguments}};
    if ($command eq "list-git-directories") {
        print("$dir\n");
        return;
    }

    my $format = $self->{format};
    if (!defined $format) {
        $format = $self->{no_brackets} ? "%s" : "[%s]";
        if ($self->{inline}) {
            $format .= $self->{no_brackets} ? ":" : " ";
        }
    }
    my $dir_header = $self->{basename} ? basename($dir) : $dir;
    if (!$self->{inline} && !$self->{errors_only}) {
        if (isVT) {
            print color('green');
        }
        printf($format, $dir_header);
        if (isVT) {
            print color('reset');
        }
        print("\n");
    }
    my $inline_prefix = $self->{inline} && sprintf($format, $dir_header);
    if (defined $self->{format_width}) {
        $inline_prefix = sprintf("%-*s", $self->{format_width}, $inline_prefix);
    }
    my $inline_separator = defined $self->{separator} ? String::Unescape->unescape($self->{separator}) : undef;
    my $use_pipes_and_such = $self->{indent} || $self->{inline} || $self->{errors_only};

    $self->{inline_separator} = $inline_separator;
    $self->{inline_prefix} = $inline_prefix;

    # git <command> <args> writes to $*_write
    # our first child process reads from $stdout_read
    # our second child process reads from $stderr_read
    my ($stdout_read, $stdout_write);
    my ($stderr_read, $stderr_write);
    if ($use_pipes_and_such) {
        if ($self->has_io_pty) {
            $stdout_read = IO::Pty->new();     # master
            $stderr_read = IO::Pty->new();     # master
            $stdout_write = $stdout_read->slave();
            $stderr_write = $stderr_read->slave();
        } else {
            pipe($stdout_read, $stdout_write) or die("pipe: $!");
            pipe($stderr_read, $stderr_write) or die("pipe: $!");
        }
    }

    my @cmd = ($command, @arguments);
    if (!$self->{no_git}) {
        unshift(@cmd, "git");
    }

    if ($self->{verbose} || $self->{dry_run}) {
        warn(sprintf("+ %s\n", shell_quote(@cmd)));
    }

    if ($self->{dry_run}) {
        return;
    }

    my %proc;
    my $spork = $self->{spork} //= My::Git::All::Spork->new(
        die => 1,
    );

    my $wait = sub {
        my ($pid, $status, $exit, $signal, $coredump, $data) = @_;
        if ($status) {
            if ($self->{verbose}) {
                my $msg = "@$data";
                if ($exit) {
                    $msg .= " exited with status $exit";
                }
                if ($signal) {
                    $msg .= " killed by signal $signal";
                }
                if ($coredump) {
                    $msg .= " dumped core";
                }
                warn("$msg\n");
            }
        }
    };

    my $data = [@cmd];
    if ($cmd[0] eq 'git') {
        splice(@$data, 2);
    }

    my $pid = $spork->fork(
        start => sub {
            if (defined $reldir && $reldir ne ".") {
                if (!chdir($reldir)) {
                    die("chdir $reldir: $!");
                }
            }
            if ($use_pipes_and_such) {
                open(STDOUT, ">&", $stdout_write) or die("open: $!");
                open(STDERR, ">&", $stderr_write) or die("open: $!");
            }
            if (!exec(@cmd)) {
                die("exec $cmd[0]: $!");
            }
        },
        done => sub {
            my ($pid, $status, $exit, $signal, $coredump, $data) = @_;
            $wait->($pid, $status, $exit, $signal, $coredump, $data);
        },
        data => [@cmd],
    );

    my ($pid1, $pid2);

    if ($self->{errors_only}) {
        close($stdout_write) or die("close: $!");
        close($stderr_write) or die("close: $!");

        STDOUT->autoflush(1);
        if (-t 1) {
            if (!$self->{no_progress}) {
                # show each project while git <cmd> is doing its work
                # on it.
                if (isVT) {
                    print(color('green'));
                }
                printf($format, $dir_header);
                if (isVT) {
                    print(color('reset'));
                }
            }
        }

        my $clear_to_eol = (-t 1) ? `tput ce` : "\n";

        my $rin = '';
        vec($rin, fileno($stdout_read), 1) = 1;
        vec($rin, fileno($stderr_read), 1) = 1;

        my @lines;

        while (1) {
            my $rout = $rin;
            my $nfound = select(
                $rout,
                undef,
                undef,
                undef
            );
            if ($nfound == -1) {
                warn("select: $!\n");
                last;
            }
            if (!$nfound) {
                last;
            }
            if (vec($rout, fileno($stdout_read), 1)) {
                my $line = <$stdout_read>;
                if (defined $line) {
                    push(@lines, { fh => "stdout", line => $line });
                } else {
                    if ($!) {
                        warn("read: $!\n");
                    }
                    last;
                }
            }
            if (vec($rout, fileno($stderr_read), 1)) {
                my $line = <$stderr_read>;
                if (defined $line) {
                    push(@lines, { fh => "stderr", line => $line });
                } else {
                    if ($!) {
                        warn("read: $!\n");
                    }
                    last;
                }
            }
        }
        my $done = sub {
            my ($pid, $status, $exit, $signal, $coredump, $data) = @_;
            if (-t 1) {
                if ($self->{no_progress}) {
                    if (isVT) {
                        print(color('green'));
                    }
                    printf($format, $dir_header);
                    if (isVT) {
                        print(color('reset'));
                    }
                }
                if ($status) {
                    if (!$self->{inline}) {
                        # keep project name visible on terminal
                        print "\n";
                    } else {
                        # erase project name, no newline
                        print "\r${clear_to_eol}";
                    }
                } else {
                    # erase project name, no newline
                    print "\r${clear_to_eol}";
                }
            } else {
                if ($status) {
                    if (isVT) {
                        print(color('green'));
                    }
                    printf($format, $dir_header);
                    if (isVT) {
                        print(color('reset'));
                    }
                    print("\n");
                }
            }
            $wait->($pid, $status, $exit, $signal, $coredump, $data);
            if ($status) {
                foreach my $line (@lines) {
                    $self->stdout($line->{line}) if $line->{fh} eq "stdout";
                    $self->stderr($line->{line}) if $line->{fh} eq "stderr";
                }
            }
        };
        $spork->done($pid, $done);
        $spork->waitx();
    } elsif ($use_pipes_and_such) {
        close($stdout_write) or die("close: $!");
        close($stderr_write) or die("close: $!");

        my $pid1 = $spork->fork(
            start => sub {
                close($stderr_read) or die("close: $!");
                select STDOUT; $| = 1;
                local $_;
                while (<$stdout_read>) {
                    $self->stdout($_);
                }
                close($stdout_read) or die("close: $!");
            },
            done => sub {
                my ($pid, $status, $exit, $signal, $coredump, $data) = @_;
                $wait->($pid, $status, $exit, $signal, $coredump, $data);
            },
            data => ["stdout pipe"],
        );
        $proc{$pid1} = "stdout pipe";

        my $pid2 = $spork->fork(
            start => sub {
                close($stdout_read) or do {
                    if ($!{EBADF}) {
                        exit(1);
                    }
                    die("close: $!");
                };
                select STDERR; $| = 1;
                local $_;
                while (<$stderr_read>) {
                    $self->stderr($_);
                }
                close($stderr_read) or die("close: $!");
            },
            done => sub {
                my ($pid, $status, $exit, $signal, $coredump, $data) = @_;
                $wait->($pid, $status, $exit, $signal, $coredump, $data);
            },
            data => ["stderr pipe"],
        );
        $proc{$pid2} = "stderr pipe";

        close($stdout_read) or do {
            if ($!{EBADF}) {
                exit(1);
            }
            die("close: $!");
        };
        close($stderr_read) or do {
            if ($!{EBADF}) {
                exit(1);
            }
            die("close: $!");
        };
    }
    $spork->waitx();
}

sub child_error_info {
    my ($self, $status) = @_;
    $status //= $?;

    my $exit     = $status >> 8;
    my $signal   = $status & 127;
    my $coredump = ($status & 128) ? 1 : 0;
    if (wantarray) {
        return ($exit, $signal, $coredump);
    } else {
        return {
            exit     => $exit,
            signal   => $signal,
            coredump => $coredump
        };
    }
}

sub warn_child_error {
    my ($self, $status, @child) = @_;
    $status //= $?;

    my ($exit, $signal, $coredump) = $self->child_error_info($status);
    if ($exit || $signal || $coredump) {
        my @message;
        push(@message, "returned $exit")      if $exit;
        push(@message, "with signal $signal") if $signal;
        push(@message, "core dumped")         if $coredump;
        my $message = join(", ", @message);
        if (!scalar @child) {
            @child = ("child");
        }
        warn("@child died: $message\n");
    }
}

1;
