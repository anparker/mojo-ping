package Mojo::Ping::ICMP::Packet;
use Mojo::Base '-base';

use Carp 'croak';

use constant ICMP_STRUCT => 'C2n3a*';
use constant {
  ICMP_ECHO_REPLY    => 0,
  ICMP_DEST_UNREACH  => 3,
  ICMP_ECHO_REQ      => 8,
  ICMP_TIME_EXCEEDED => 11,
};

has data => sub {
  my $data = '';
  for (my $cnt = 0; $cnt < $_[0]->length; $cnt++) { $data .= chr($cnt % 255) }
  return $data;
};
has length => 56;
has [qw(code id seq_num type)] => 0;


sub assemble {
  my $self = shift;

  my $bytes = pack ICMP_STRUCT, ICMP_ECHO_REQ, 0, 0,
    ($self->{id} //= int(rand 0x10000)), ($self->{seq_num} //= 0), $self->data;

  my $cksum = $self->_icmp_checksum($bytes);
  substr $bytes, 2, 2, pack('n', $cksum);

  return $bytes;
}

sub inc_seq {
  $_[0]->seq_num(++$_->{seq_num});
}

sub new {
  @_ == 2 ? shift->SUPER::new()->parse(@_) : shift->SUPER::new(@_);
}

sub parse {
  my ($self, $msg) = @_;

  croak 'Corrupted packet buffer.' unless $msg && $self->_verify_checksum($msg);

  @{$self}{qw(type code id seq_num data)}
    = (unpack ICMP_STRUCT, $msg)[0 .. 1, 3 .. 5];

  return $self;
}

sub _icmp_checksum {
  my ($self, $msg) = @_;

  my $res = 0;
  $res += $_ for (unpack "n*", $msg);

  # Add odd byte
  $res += unpack('C', substr($msg, -1, 1)) << 8 if length($msg) % 2;

  # Fold high into low, twice
  $res = ($res >> 16) + ($res & 0xffff);
  $res = ($res >> 16) + ($res & 0xffff);

  return ~$res & 0xffff;
}

sub _verify_checksum {
  my ($self, $msg) = @_;

  # current checksum
  my $cur_sum = substr $msg, 2, 2;

  # replace checksum with 0s.
  substr($msg, 2, 2) = pack 'n', 0x0000;

  # calculate new checksum
  my $new_sum = pack 'n', $self->_icmp_checksum($msg);

  return !!($cur_sum eq $new_sum);
}


1;


__END__

=encoding utf8

=head1 NAME

Mojo::Ping::ICMP::Packet - just an ICMP packet.

=head1 SYNOPSIS

  my $packet = Mojo::Ping::ICMP::Packet->new();
  my $bytes = $packet->assemble();

  $packet = Mojo::Ping::ICMP::Packet->new($bytes);

=head1 DESCRIPTION

L<Mojo::Ping::ICMP::Packet> - represent ICMP packet to work with.

=head1 ATTRIBUTES

=head2 code

  my $code = $packet->code;
  $packet  = $packet->code(0);

ICMP subtype. Should be C<0> for ECHO messages.

=head2 data 

  my $data = $packet->data;
  $packet  = $packet->data($bytes);

Payload. Unless provided, will be automatically generated L</length> bytes long.

=head2 id

  my $id  = $packet->id;
  $packet = $packet->id(int(rand(0x10000)));

Value of ICMP packet identifier field. Defaults to a random value.

=head2 length

  my $len = $packet->length;
  $packet = $packet->length(1472);

Number of data bytes to generate. Resulting packet size will be L</length> +
C<8> bytes (ICMP header). Defaults to C<56>.

=head2 seq_num

  my $seq = $packet->seq_num;
  $packet = $packet->seq_num(0);

Current sequence number.

=head2 type

  my $type = $packet->type;
  $packet  = $packet->type(0);

ICMP type.

=head1 METHODS

=head2 assemble;

  my $bytes = $packet->assemble();

Assembles ICMP echo request packet.

=head2 inc_seq

  my $packet = $packet->inc_seq();

Increments sequence number by C<1>.

=head2 new

  my $packet = Mojo::Ping::ICMP::Packet->new();

  # or

  $packet = Mojo::Ping::ICMP::Packet->new($bytes);

Object constructor. Treats single argument as a packet buffer.

=head2 parse

  $packet->parse($bytes);

Parses data from buffer.

=head1 SEE ALSO

L<https://tools.ietf.org/html/rfc792>

=cut
