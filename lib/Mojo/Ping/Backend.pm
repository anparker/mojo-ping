package Mojo::Ping::Backend;
use Mojo::Base 'Mojo::EventEmitter';

use Carp 'croak';

sub error { croak 'Method "error" not implemented by subclass' }
sub ping { croak 'Method "ping" not implemented by subclass' }

1;

__END__

=encoding utf8

=head1 NAME

Mojo::Ping::Backend - Backend base class.

=head1 SYNOPSIS

=head1 DESCRIPTION

Abstract base class for L<Mojo::Ping> backends.

=head1 ATTRIBUTES

=head1 METHODS

=head2 error

  my $err = $backend->error()

Returns last occurred error. Should be overloaded in a subclass.

=head2 ping

  # blocking
  my $available = $backend->ping('localhost');

  # non-blocking
  $backend->ping('localhost' => sub {
    my ($p, $avail, $err) = @_;
    ...
  });
  Mojo::IOLoop->start() unless Mojo::IOLoop->is_running();

Probe specified host. Should be overloaded in a subclass.

=cut
