
use Mojo::IOLoop;
use Mojo::Ping::ICMP;
use Scalar::Util 'looks_like_number';
use Test::More;
use Time::HiRes 'time';

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};
plan skip_all =>
  'set ICMP_WITHOUT_ROOT to run this test without superuser privileges'
  if ($< != 0 || $> != 0) && !$ENV{ICMP_WITHOUT_ROOT};

my $icmp = Mojo::Ping::ICMP->new();
isa_ok $icmp, 'Mojo::Ping::ICMP', 'right class';

my $res = $icmp->ping('a.long.time.ago.in.a.galaxy.far.far.away');
is $res, '', 'no response';
my $err = $icmp->error();
is $err, 'hostname nor servname provided, or not known',
  'right error, unknown hostname';

$res = $icmp->ping('127.0.0.1');
ok looks_like_number($res), 'right response';
ok !$icmp->error(), 'no error';

$icmp->timeout(0.25)->retries(2);
my $start = time;
$res = $icmp->ping('127.0.0.10');
ok time - $start < 0.6, 'timeout timing looks fine';
is $res, '', 'no response on timeout';
is $icmp->error(), 'response timeout', 'right error, timeout';

my ($err2, $err3, $res2, $res3);
$icmp->retries(1);
$icmp->ping('127.0.0.1' => sub { shift; ($res,  $err)  = @_; });
$icmp->ping('127.0.0.1' => sub { shift; ($res2, $err2) = @_; });
$icmp->ping(
  '127.0.0.10' => sub { shift; ($res3, $err3) = @_; Mojo::IOLoop->stop(); });

# Mojo::IOLoop->timer(1 => sub { Mojo::IOLoop->stop() });
Mojo::IOLoop->start();
ok looks_like_number($res), 'non-blocking response 1';
ok !$err, 'non-blocking no error 1';
ok looks_like_number($res2), 'non-blocking response 2';
ok !$err2, 'non-blocking no error 2';
is $res3, '', 'non-blocking no response 3';
is $err3, 'response timeout', 'non-blocking right error 3';

{
  $err = '';
  local $SIG{__WARN__} = sub { $err = $_[0] };
  $icmp->timeout(0.25)->retries(1);
  $icmp->ping('127.0.0.1' => sub { $err = 'got responce'; Mojo::IOLoop->stop() }
  );
  Mojo::IOLoop->next_tick(sub { $icmp = undef });
  Mojo::IOLoop->timer(0.3 => sub { Mojo::IOLoop->stop() });
  Mojo::IOLoop->start();
  is $err, '', 'no warning on destroy with pending requests'
}

done_testing();
