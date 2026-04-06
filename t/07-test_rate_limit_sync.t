#!perl

use strict;
use warnings;

BEGIN { *CORE::GLOBAL::sleep = sub { }; }

use Test::More;
use Net::Jabber::Bot;

use FindBin;
use lib "$FindBin::Bin/lib";
use MockJabberClient;

my $server = 'jabber.example.com';

my %forums = ( 'test_room' => ["bot:"] );

# Helper to create a bot with given options merged onto defaults
sub make_bot {
    my %opts = @_;
    return Net::Jabber::Bot->new(
        server               => $server,
        conference_server     => "conference.$server",
        port                 => 5222,
        username             => 'testuser',
        password             => 'testpass',
        alias                => 'test_bot',
        message_function     => sub { },
        background_function  => sub { },
        forums_and_responses => \%forums,
        forum_join_grace     => 0,
        max_messages_per_hour => 1000,
        %opts,
    );
}

subtest 'construction: message_delay matches out_messages_per_second' => sub {
    my $bot = make_bot( out_messages_per_second => 4 );
    is( $bot->message_delay, 1 / 4, "message_delay is 1/out_messages_per_second at construction" );
};

subtest 'runtime: changing out_messages_per_second updates message_delay' => sub {
    my $bot = make_bot( out_messages_per_second => 5 );
    is( $bot->message_delay, 0.2, "initial message_delay is 0.2" );

    $bot->out_messages_per_second(2);
    is( $bot->message_delay, 0.5, "message_delay updated to 0.5 after changing rate to 2/s" );

    $bot->out_messages_per_second(10);
    is( $bot->message_delay, 0.1, "message_delay updated to 0.1 after changing rate to 10/s" );
};

subtest 'runtime: direct message_delay change does not affect out_messages_per_second' => sub {
    my $bot = make_bot( out_messages_per_second => 5 );
    $bot->message_delay(1);
    is( $bot->out_messages_per_second, 5, "out_messages_per_second unchanged by direct message_delay set" );
};

subtest 'safety mode: BUILD still clamps message_delay after trigger' => sub {
    # safety_mode is on by default. out_messages_per_second => 10 would give
    # message_delay 0.1, but safety clamps to 1/5 = 0.2
    my $bot = make_bot( out_messages_per_second => 10, safety_mode => 1 );
    cmp_ok( $bot->message_delay, '>=', 0.2, "safety mode clamps message_delay to >= 0.2" );
    is( $bot->get_safety_mode, 1, "bot is in safety mode" );
};

subtest 'no safety: high rate is allowed' => sub {
    my $bot = make_bot( out_messages_per_second => 10, safety_mode => 0 );
    is( $bot->message_delay, 0.1, "without safety, message_delay follows out_messages_per_second" );
};

done_testing;
