
use Mojo::Ping;
use Test::More;

my $ping = Mojo::Ping->new();
isa_ok $ping, 'Mojo::Ping', 'right class';
isa_ok $ping->backend, 'Mojo::Ping::ICMP', 'right default backend';

{
  eval { $ping = Mojo::Ping->new('DummyPing') };
  ok $@ =~ /Missing backend for "Mojo::Ping::DummyPing"/,
    'right error, missing backend';
}

done_testing();
