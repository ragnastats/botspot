package Botspot;
 
# Perl includes
use strict;
use Data::Dumper;
use Time::HiRes;
use List::Util;
use Storable;
 
# Kore includes
use Settings;
use Plugins;
use Network;
use Globals;
use Utils;

my $botspot = {'priest'		=> 'Warp Drive Active',
				'wizard'	=> 'Chilling Effects',
				'knight'	=> 'A Little Nudge'
				};
my $step = {'priest' => 0, 'wizard' => 0, 'knight' => 0};

Commands::register(["dunk", "Gonna get dunked", \&start]);
Plugins::register("Botspot", "Dunk them spammers", \&unload);

my $hooks = Plugins::addHooks(["packet_privMsg", \&parseChat],
								["packet_partyMsg", \&parseChat]);
								
								
sub unload
{
	Plugins::delHooks($hooks);
}

sub parseChat
{
	my($hook, $args) = @_;
	my $user = $args->{MsgUser};
	my $message = $args->{Msg};
	
	print("$message\n");
	
	if($message =~ m/^Arrived at ([0-9]+), ([0-9]+)$/)
	{
		my $arrived = {x => $1, y => $2};
	
		print(Dumper($botspot->{pos}));
		print(Dumper($arrived));
		
		my $distance = distance($botspot->{pos}, $arrived);
		print(Dumper($distance));
	
		if($user == $botspot->{priest})
		{
			if($step->{priest} == 0)
			{
				$botspot->{warpPos} = {x => $pos->{x}, $pos->{y}};
				if($distance < 2) 
				{
					my $offset = {'x'		 => int(rand()) + 1,
								  'y'		 => int(rand()) + 1
					};
					if (int(rand()) == 0) {
						$offset->{x} *= -1;
					}
					if (int(rand()) == 0) {
						$offset->{y} *= -1;
					}
					$step->{priest} += 1
					Commands::run("pm '$botspot->{priest}' exec move " . $offset->{x} + $arrived->{x} . " " . $offset->{y} + $arrived->{y});
				}
				else
				{
					print(Dumper("We can't dunk this man. He is undunkable."));
				}
			} 
			elsif($step->{priest} == 1)
			{
				my $pos = calcPosition($char);
				if($pos->{x} == $botspot->{warpPos}->{x})
				{
					if($pos->{y} == $botspot->{warpPos}->{y})
					{
						my $offset = {'x'		 => int(rand()) + 1,
									  'y'		 => int(rand()) + 1
						};
						if (int(rand()) == 0) {
							$offset->{x} *= -1;
						}
						if (int(rand()) == 0) {
							$offset->{y} *= -1;
						}
						Commands::run("pm '$botspot->{priest}' exec move " . $offset->{x} + $arrived->{x} . " " . $offset->{y} + $arrived->{y});
					}
					else
					{
						$step->{priest} += 1;
					}
				}
				else
				{
					$step->{priest} += 1;
				}
			}
			else
			{
				Commands::run("pm '$botspot->{priest}' exec sl 27 '$arrived->{x}' '$arrived->{y}'");
				Commands::run("pm '$botspot->{wizard}' ");
			}
		}
		elsif($user == $botspot->{wizard})
		{
			freeze();
			Commands::run("pm '$botspot->{knight}' move '$arrived->{x}' '$arrived->{y}'");
		}
		elsif($user == $botspot->{knight})
		{
			dunk();
		}
	}
}

sub start
{
	my($command, $target) = @_;
	my $player = Match::player($target, 1);

	if($player)
	{
		my $pos = calcPosition($player);
		$botspot->{target} = $player;
		$botspot->{pos} = $pos;
		
		print("Player '$player->{name}' matched at $pos->{x}, $pos->{y}\n");
		
		Commands::run("pm '$botspot->{priest}' exec move $pos->{x} $pos->{y}");
	}
	else
	{
		print("No players matched\n");
	}
}

sub freeze
{
	
}

sub dunk
{
	
}

1;