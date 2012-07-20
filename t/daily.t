use strict;
use warnings;

use RT::Extension::RepeatTicket::Test tests => 35;

use_ok('RT::Extension::RepeatTicket');
require_ok('bin/rt-repeat-ticket');

{
    my ( $baseurl, $m ) = RT::Test->started_ok();

    diag "Run with default coexist value of 1";
    my $daily_id = run_tests($baseurl, $m);

    ok(!(RT::Repeat::Ticket::Run->run()), 'Ran recurrence script for today.');

    my $next_id = $daily_id + 1;
    my $ticket = RT::Ticket->new(RT->SystemUser);
    ok( !($ticket->Load($next_id)), "No ticket created for today.");

    my $tomorrow = DateTime->now->add( days => 1 );
    ok(!(RT::Repeat::Ticket::Run->run('-date=' . $tomorrow->ymd)), 'Ran recurrence script for tomorrow.');
    ok( $m->goto_ticket($next_id), "Recurrence ticket $next_id created for tomorrow.");
    $m->text_like( qr/Set up recurring aperture maintenance/);
}

RT::Test->stop_server;

{
    RT->Config->Set('RepeatTicketCoexistentNumber', 2);
    my ( $baseurl, $m ) = RT::Test->started_ok();

    diag "Run with Coexistent value of 2";
    my $daily_id = run_tests($baseurl, $m);
    ok(!(RT::Repeat::Ticket::Run->run()), 'Ran recurrence script for today.');

    my $second = $daily_id + 1;
    ok( $m->goto_ticket($second), 'Recurrence ticket created for today.');
    $m->text_like( qr/Set up recurring aperture maintenance/);

    my $tomorrow = DateTime->now->add( days => 1 );
    ok(!(RT::Repeat::Ticket::Run->run('-date=' . $tomorrow->ymd)), 'Ran recurrence script for tomorrow.');

    my $third = $daily_id + 2;
    my $ticket = RT::Ticket->new(RT->SystemUser);
    ok( !($ticket->Load($third)), "Third ticket $third not created.");

    $ticket->Load($second);
    ok($ticket->SetStatus('resolved'), "Ticket $third resolved");
    ok(!(RT::Repeat::Ticket::Run->run()), 'Ran recurrence script for today.');

    ok( $m->goto_ticket($third), "Recurrence ticket $third created.");
    $m->text_like( qr/Set up recurring aperture maintenance/);
    RT::Test->stop_server;
}


sub run_tests{
    my ($baseurl, $m) = @_;

    ok( $m->login( 'root', 'password' ), 'logged in' );

    $m->submit_form_ok({
                        form_name => 'CreateTicketInQueue',
                        fields    => {
                                      'Queue' => 'General' },
                       }, 'Click to create ticket');

    $m->content_contains('Enable Recurrence');

    diag "Create a ticket with a recurrence in the General queue.";

    $m->submit_form_ok({
                        form_name => 'TicketCreate',
                        fields    => {
                                      'Subject' => 'Set up recurring aperture maintenance',
                                      'Content' => 'Perform work on portals once per day',
                                      'repeat-enabled' => 1,
                                      'repeat-type' => 'daily',
                                      'repeat-details-daily' => 'day',
                                      'repeat-details-daily-day' => 1,
                                     },}, 'Create');

    $m->text_like( qr/Ticket\s(\d+)\screated in queue/);

    my ($daily_id) = $m->content =~ /Ticket\s(\d+)\screated in queue/;
    ok($daily_id, "Created ticket with id: $daily_id");
    return $daily_id;
}