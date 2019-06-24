use v6;
use Test;

#
# Copyright © 2018-2019 Joelle Maslak
# All Rights Reserved - See License
#

$*OUT.out-buffer = False;

use TCP::LowLevel;

subtest 'Perl Native Sockets', {
    temp $TCP::LowLevel::linux = False;
    do-test;
}

subtest 'Perl Native Sockets (Bin)', {
    temp $TCP::LowLevel::linux = False;
    do-test(:bin);
}

subtest 'Linux Sockets', {
    plan :skip-all("Not Linux") unless $TCP::LowLevel::linux;
    do-test;
}

subtest 'Linux Sockets (Bin)', {
    plan :skip-all("Not Linux") unless $TCP::LowLevel::linux;
    do-test(:bin);
}

subtest 'MD5 Sockets', {
    plan :skip-all("No MD5 Support") unless TCP::LowLevel.supports-md5;
    do-test('test test test');
}

subtest 'MD5 Sockets (Failure with unsigned client)', {
    plan :skip-all("No MD5 Support") unless TCP::LowLevel.supports-md5;
    do-fail-test('test test test');
}

subtest 'MD5 Sockets (Failure with client having bad signature)', {
    plan :skip-all("No MD5 Support") unless TCP::LowLevel.supports-md5;
    do-fail-test('test test test', 'bogus bogus bogus');
}

done-testing;

sub do-test($md5?, Bool :$bin?) {
    #
    # Server
    #
    react {
        #
        # Server
        #
        my $server-tcp = TCP::LowLevel.new;

        if $md5.defined {
            $server-tcp.add-md5('127.0.0.1', $md5);
        }

        $server-tcp.listen;
    
        # Handle incomming connections
        whenever $server-tcp.acceptor -> $conn {
            # Simple echo server
            whenever $conn.Supply(:$bin) -> $msg {
                if $bin {
                    $conn.write: $msg;
                } else {
                    $conn.print: $msg;
                }
            }
        }

        my $port = $server-tcp.socket-port.result;
        is $port > 0, True, "Port is defined and > 0";
        diag "Server port: $port";
        

        #
        # Testing Infrastructure
        #

        # We use this for the client to signal back to the test harness.
        my $supply = Supplier::Preserving.new;


        #
        # Client
        #
        my $client-tcp = TCP::LowLevel.new;

        if $md5.defined {
            $client-tcp.add-md5('127.0.0.1', $md5);
        }

        my $conn = $client-tcp.connect('127.0.0.1', $port).result;

        whenever $conn.Supply(:$bin) -> $msg {
            my $line = $bin ?? $msg.decode !! $msg;
            $supply.emit: $line.chomp;
        }


        #
        # Test Harness
        #
        my @items = (^5).list;
        my $message = "∞ " ~ @items.shift;
        $conn.print: "$message\n"; # We use print for binary mode to make sure it works

        whenever $supply -> $received {
            is $received, $message, "Message '$message'";

            if @items {
                $message = @items.shift;
                if $bin {
                    $conn.write: buf8.new("$message\n".encode); # Need to test write in bin mode
                } else {
                    $conn.print: "$message\n";
                }
            } else {
                done;
            }
        }
    }

    done-testing;
}

sub do-fail-test($server-md5?, $client-md5?) {
    #
    # Server
    #
    react {
        #
        # Server
        #
        my $server-tcp = TCP::LowLevel.new;

        if $server-md5.defined {
            $server-tcp.add-md5('127.0.0.1', $server-md5);
        }

        $server-tcp.listen;
    
        # Handle incomming connections
        whenever $server-tcp.acceptor -> $conn {
            # Simple echo server
            whenever $conn -> $line {
                flunk "Received something we shouldn't have";
                done;
            }
        }

        my $port = $server-tcp.socket-port.result;
        is $port > 0, True, "Port is defined and > 0";
        diag "Server port: $port";
        

        #
        # Client
        #
        my $client-tcp = TCP::LowLevel.new;

        if $client-md5.defined {
            $client-tcp.add-md5('127.0.0.1', $client-md5);
        }

        my $conn-promise = $client-tcp.connect('127.0.0.1', $port);


        #
        # Test Harness
        #
        whenever $conn-promise -> $conn {
            $conn.print: "This doesn't matter\n";
        }

        whenever Promise.in(.1) {
            pass "Timeout reached";
            done;
        }
    }

    done-testing;
}

