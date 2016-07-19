package Mojo::Ping;
use Mojo::Base '-base';

use Carp 'croak';
use Mojo::Loader 'load_class';
use Scalar::Util 'weaken';

our $VERSION = '0.01';

has 'backend';

sub new {
  my $self = shift->SUPER::new();

  my $backend = shift // 'ICMP';
  my $class   = "Mojo::Ping::$backend";
  my $e       = load_class $class;
  croak ref $e ? $e : qq{Missing backend for "$class".} if $e;
  $self->backend($class->new(@_));

  return $self;
}

sub error {
  shift->backend->error();
}

sub ping {
  shift->backend->ping(@_);
}

1;

__END__

=encoding utf8

=head1 NAME

Mojo::Ping - probe host for availability.

=head1 SYNOPSIS

=head1 DESCRIPTION

Simple and either blocking or non-blocking way to probe remote host for
availability using one of the backends. Using ICMP backend may require superuser
privileges on most systems.

=head1 ATTRIBUTES

=head2 backend

  my $backend = $p->backend;
  $p = $p->backend(Mojo::Ping::ICMP->new());

Backend. Only available backend for now is L<Mojo::Ping::ICMP>.

=head1 METHODS

=head2 new 

  my $p = Mojo::Ping->new();

  # or

  $p = Mojo::Ping->('ICMP' => {timeout => 3});

Construct L<Mojo::Ping> object with a selected backend. Defaults to C<ICMP>.

=head2 error

  my $err = $icmp->error();

Returns last occurred error.

=head2 ping

  # blocking
  my $avail = $p->ping('localhost');

  # non-blocking
  $p->ping('localhost' => sub {
    my ($backend, $avail, $err) = @_;
    ...
  });
  Mojo::IOLoop->start() unless Mojo::IOLoop->is_running();

Probe specified host using L</backend>. Will return true value if host is
available and false otherwise. Actual values may differ between
backends.

=head1 INFO

Andre Parker <andreparker@gmail.com>.

=head1 LICENSE
This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
