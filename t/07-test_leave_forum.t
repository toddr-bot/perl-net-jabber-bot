#!perl

use strict;
use warnings;
use Test::More tests => 14;
use Net::Jabber::Bot;

use FindBin;
use lib "$FindBin::Bin/lib";
use MockJabberClient;

my $bot_alias = 'leave_test_bot';
my $server    = 'talk.google.com';

my %forums_and_responses;
$forums_and_responses{'room1'} = [ "bot:", "" ];
$forums_and_responses{'room2'} = [ "bot:", "" ];

my $bot = Net::Jabber::Bot->new(
    server               => $server,
    conference_server     => "conference.$server",
    port                 => 5222,
    username             => 'test_username',
    password             => 'test_pass',
    alias                => $bot_alias,
    message_function     => sub { },
    background_function  => sub { },
    loop_sleep_time      => 5,
    process_timeout      => 5,
    forums_and_responses => \%forums_and_responses,
    out_messages_per_second => 5,
    max_message_size       => 800,
    max_messages_per_hour  => 100,
    forum_join_grace       => 0,
);

isa_ok( $bot, "Net::Jabber::Bot" );
ok( $bot->IsConnected(), "Bot is connected" );

# Both forums should have join times from construction
ok( defined $bot->forum_join_time->{'room1'}, "room1 has join time" );
ok( defined $bot->forum_join_time->{'room2'}, "room2 has join time" );

# Test 1: LeaveForum sends unavailable presence and clears join time
{
    my $client = $bot->jabber_client;
    my $before_count = scalar @{ $client->{presence_send_log} };

    my $result = $bot->LeaveForum('room1');
    ok( $result, "LeaveForum returns true on success" );

    # Check that an unavailable presence was sent
    my @new_presences = @{ $client->{presence_send_log} }[ $before_count .. $#{ $client->{presence_send_log} } ];
    is( scalar @new_presences, 1, "One presence sent for LeaveForum" );
    is( $new_presences[0]->{type}, 'unavailable', "Presence type is unavailable" );
    like( $new_presences[0]->{to}, qr/^room1\@conference\.\Q$server\E\/\Q$bot_alias\E$/,
        "Presence sent to correct room JID with nick" );

    # Join time should be removed
    ok( !defined $bot->forum_join_time->{'room1'}, "room1 join time removed after leave" );

    # room2 should be unaffected
    ok( defined $bot->forum_join_time->{'room2'}, "room2 join time still present" );
}

# Test 2: LeaveForum does not remove from forums_and_responses
ok( exists $bot->forums_and_responses->{'room1'},
    "forums_and_responses still contains room1 after leave" );

# Test 3: LeaveForum while disconnected returns undef
$bot->Disconnect();
my $result = $bot->LeaveForum('room2');
ok( !defined $result, "LeaveForum returns undef when disconnected" );

# Test 4: Can rejoin a forum after leaving
$bot->ReconnectToServer();
$bot->LeaveForum('room2');
ok( !defined $bot->forum_join_time->{'room2'}, "room2 join time cleared" );
$bot->JoinForum('room2');
ok( defined $bot->forum_join_time->{'room2'}, "room2 has new join time after rejoin" );
