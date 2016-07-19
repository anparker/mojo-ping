
use Mojo::Ping::ICMP::Packet;
use Test::More;

my $p = Mojo::Ping::ICMP::Packet->new();
isa_ok $p, 'Mojo::Ping::ICMP::Packet', 'right class';

$p->length(40);
is length $p->data, 40, 'right payload length';

is $p->seq_num, 0, 'initial sequence number';
$p->inc_seq()->inc_seq();
is $p->seq_num, 2, 'right sequence number';

$p->id(0x10);
my $bytes = $p->assemble();
is length $bytes, 48, 'right packet length';

my $p2 = Mojo::Ping::ICMP::Packet->new($bytes);
is $p2->id, 0x10, 'right identifier';
is $p2->seq_num,    2,    'right sequence number';
is $p2->data, $p->data, 'right payload';

{
  my $err = '';
  local $SIG{__DIE__} = sub { $err = $_[0] };
  eval { $p = Mojo::Ping::ICMP::Packet->new('') };
  ok $err =~ /^Corrupted packet buffer./, 'right error (empty buffer)';

  $err = '';
  eval { $p = Mojo::Ping::ICMP::Packet->new($bytes . 'yey!') };
  ok $err =~ /^Corrupted packet buffer./, 'right error (wrong checksum)';
}

done_testing();
