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
                'knight'	=> 'A Little Nudge'};
                
my $step = {'priest' => 0, 'wizard' => 0, 'knight' => 0};

Commands::register(["dunk", "Gonna get dunked", \&start]);
Plugins::register("Botspot", "Dunk them spammers", \&unload);

my $hooks = Plugins::addHooks(["packet_privMsg", \&parseChat],
                                ["packet_partyMsg", \&parseChat]);
                            
                                
sub unload
{
    Plugins::delHooks($hooks);
}

sub randomPos
{
    my($pos) = @_;
    
    my $offset = {
        'x' => int(rand(2)) + 1,
        'y' => int(rand(2)) + 1
    };
    
    if(int(rand(2))) {
        $offset->{x} *= -1;
    }
    if(int(rand(2))) {
        $offset->{y} *= -1;
    }

    return {x => $offset->{x} + $pos->{x},
            y => $offset->{y} + $pos->{y}};    
}

sub parseChat
{
    my($hook, $args) = @_;
    my $user = $args->{MsgUser};
    my $message = $args->{Msg};
        
    if($message =~ m/^Arrived at ([0-9]+), ([0-9]+)$/)
    {
        my $arrived = {x => $1, y => $2};
    
        if($user == $botspot->{priest})
        {
            if($step->{priest} == 0)
            {
                my $distance = distance($botspot->{pos}, $arrived);
            
                # The server moves us to the nearest available cell around the spammer
                if($distance < 2) 
                {
                    # Move off the current cell before casting warp
                    my $random = randomPos($arrived);
                    Commands::run("pm '$botspot->{priest}' exec move $random->{x} $random->{y}");

                    $botspot->{warpPos} = {x => $arrived->{x}, y =>$arrived->{y}};
                    $step->{priest} += 1
                }
                
                # The spammer is surrounded by people and can't be warped easily :(
                else
                {
                    print("We can't dunk this man. He is undunkable.\n");
                }
            } 
            elsif($step->{priest} == 1)
            {
                # We tried to move randomly, but did we actually move off the warp position?
                if($arrived->{x} == $botspot->{warpPos}->{x} and $arrived->{y} == $botspot->{warpPos}->{y})
                {
                    my $random = randomPos($arrived);
                    Commands::run("pm '$botspot->{priest}' exec move $random->{x} $random->{y}");
                }
                
                # If so, cast warp!
                else
                {
                    Commands::run("pm '$botspot->{priest}' exec sl 27 $botspot->{warpPos}->{x} $botspot->{warpPos}->{y}");
                    $step->{priest} += 1;
                    
                    # Start the freeze
                    freeze();
                }
            }
        }
        elsif($user == $botspot->{wizard})
        {
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
      
        # Reset steps in case this isn't the first dunk
        $step = {'priest' => 0, 'wizard' => 0, 'knight' => 0};        
        
        # Tell our priest to walk on top of the spammer
        Commands::run("pm '$botspot->{priest}' exec move $pos->{x} $pos->{y}");
    }
    else
    {
        print("No players matched\n");
    }
}

sub freeze
{
    print("It's about to get chilly...\n");
}

sub dunk
{
    
}

1;