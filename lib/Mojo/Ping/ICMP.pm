package Mojo::Ping::ICMP;
use Mojo::Base 'Mojo::Ping::Backend';

# use IO::Socket::IP;
use IO::Socket::INET;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Ping::ICMP::Packet;
use Mojo::Util ();
use Scalar::Util 'weaken';
use Socket qw(getaddrinfo SOCK_RAW IPPROTO_ICMP);
use Time::HiRes 'time';

has ioloop => sub { Mojo::IOLoop->new() };
has retries => 3;
has timeout => 5;

use constant DEBUG => $ENV{MOJO_PING_DEBUG} || 0;

sub DESTROY { Mojo::Util::_global_destruction() or shift->_cleanup() }

sub error { $_[0]->{error} }

sub ping {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, $host) = @_;

  # non-blocking
  return $self->_ping(Mojo::IOLoop->singleton, $host, $cb) if $cb;

  # blocking
  my $res;
  $self->_ping($self->ioloop,
    $host => sub { shift->ioloop->stop(); $res = shift; });
  $self->ioloop->start();

  return $res;
}

sub _cleanup {
  my $self = shift;
  $_->{timeout} && $_->{loop}->remove($_->{timeout})
    for values %{$self->{connections}};
  $_ && $_->unsubscribe('close')->close() for values %{$self->{handles}};
  delete $self->{handles};
}

sub _fail {
  my ($self, $c, $err) = @_;
  $c->{loop}->remove($c->{timeout});
  $c->{packet}->inc_seq() and return $self->_send_request($c)
    if ++$c->{try} < $self->retries;
  $self->_finish($c, $err);
}

sub _finish {
  my ($self, $c, $err) = @_;
  delete $self->{connections}{$c->{id}};
  if (my $timer = $c->{timeout}) { $c->{loop}->remove($timer) }
  $c->{cb}->($self, $c->{stop} ? $c->{stop} - $c->{start} : '',
    $self->{error} = $err);
}

sub _id {
  my $self = shift;
  my $id;
  do { $id = int(rand 0x10000) } while $self->{connections}{$id};
  return $id;
}

sub _open_handle {
  my ($self, $loop) = @_;

  my $handle = IO::Socket::INET->new(
    Proto    => IPPROTO_ICMP,
    Type     => SOCK_RAW,
    Blocking => 0
  ) or die "Cannot create socket - $@\n";

  # my $handle
  #   = IO::Socket::IP->new(
  #   PeerAddrInfo => [{protocol => IPPROTO_ICMP, socktype => SOCK_RAW}])
  #   or die "Cannot create socket - $@\n";

  $handle->blocking(0);
  my $stream = Mojo::IOLoop::Stream->new($handle);
  weaken $stream->reactor($loop->reactor)->{reactor};

  weaken $self;
  $stream->on(read => sub { $self->_read($_[1]) });
  $stream->on(error => sub { $self and $self->emit(error => $_[1]) });
  $stream->on(close => sub { $self and delete $self->{handles}{$loop} });

  $stream->start();

  return $stream;
}

sub _ping {
  my ($self, $loop, $host, $cb) = @_;


  my $id = $self->_id();
  my $c = $self->{connections}{$id} = {cb => $cb, id => $id, loop => $loop};

  my ($err, @list) = getaddrinfo $host;
  return $self->_finish($c, $err) if $err;

  $c->{addr} = $list[0]->{addr};

  return $self->_send_request($c);
}

sub _read {
  my ($self, $bytes) = @_;

  # skip first 20 bytes which is IP header.
  my $packet;
  eval { $packet = Mojo::Ping::ICMP::Packet->new(substr $bytes, 20); 1; }
    or return $self->emit(error => $@);

  say '-- Received response id ' . $packet->id if DEBUG;

  # skip unknown packets silently
  return unless my $c = $self->{connections}{$packet->id};

  # ignore misordered packets
  return if $packet->seq_num != $c->{packet}->seq_num;

  # we don't care about everything else
  return $self->_finish($c, 'Received packet is not an echo reply')
    if $packet->type != 0;

  $c->{stop} = time;
  $self->_finish($c);
}

sub _send_request {
  my ($self, $c) = @_;

  say '-- Sent requests id ' . $c->{id} if DEBUG;

  # clear error
  $self->{error} = '';

  # open different handles for blocking and non-blocking requests
  my $stream = $self->{handles}{$c->{loop}} ||= $self->_open_handle($c->{loop});

  my $packet = $c->{packet} ||= Mojo::Ping::ICMP::Packet->new(id => $c->{id});

  $stream->handle->send($packet->assemble, 0, $c->{addr});
  $c->{start} = time;

  weaken $self;
  $c->{timeout} = $c->{loop}
    ->timer($self->timeout => sub { $self->_fail($c, 'response timeout') });

  return $c->{id};
}

1;

__END__

=encoding utf8

=head1 NAME

Mojo::Ping::ICMP - ICMP backend for L<Mojo::Ping>.

=head1 SYNOPSIS

  my $icmp = Mojo::Ping::ICMP->new();
  $icmp->ping('localhost');

=head1 DESCRIPTION

Probe hosts using ICMP echo requests. Requires superuser privileges on most
systems.

=head1 EVENTS

=head2 error

  $icmp->on(error => sub { my ($icmp, $err) = @_ });

Emitted on errors that can't be associated with particular request.

=head1 ATTRIBUTES

=head2 ioloop

  my $ioloop = $icmp->ioloop;
  $icmp = $icmp->ioloop(Mojo::IOLoop->new());

L<Mojo::IOLoop> object to use for blocking operations.

=head2 retries

  my $retries = $icmp->retries;
  $icmp = $icmp->retries($num);  

Number of packets to send before acknowledge host as down.

=head2 timeout

  my $timeout = $icmp->timeout;
  $icmp = $icmp->timeout($sec);

Timeout in seconds before packet considered lost. Defaults to C<5>.

=head1 METHODS

=head2 error

  my $err = $icmp->error();

Returns last occurred error.

=head2 ping

  my $avail = $icmp->ping('locahost');

  # or

  $icmp->ping('localhost' => sub {
    my ($icmp, $avail, $err) = @_;
    ...
  });
  Mojo::IOLoop->start() unless Mojo::IOLoop->is_running();

Probe specified host. Will return elapsed time in seconds or an empty string if
host is unavailable.

=cut
