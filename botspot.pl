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
                
my $step = {'priest' => 1, 'wizard' => 1, 'knight' => 1};

Commands::register(["dunk", "Gonna get dunked", \&start]);
Plugins::register("Botspot", "Dunk them spammers", \&unload);

my $hooks = Plugins::addHooks(["packet_privMsg", \&parseChat],
                                ["packet_partyMsg", \&parseChat]);
                            
                                
sub unload
{
    Plugins::delHooks($hooks);
}

# Accepts a position hash and returns the same hash with slightly randomized values
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

# Accepts two position hashes and returns a new hash in a straight line and the relative heading
sub straightPos
{
    my($pos1, $pos2, $step) = @_;
    $step ||= 1;
    
    # Calculate the difference between our two hashes
    my $diffX = abs($pos1->{x} - $pos2->{x});
    my $diffY = abs($pos1->{y} - $pos2->{y});
    
    
    if($diffX)
    {    
        return
        {
            heading => 'x',
            x => $botspot->{targetPos}->{x} + $diffX * $step,
            y => $botspot->{targetPos}->{y}
        };
    }
    elsif($diffY)
    {
        return
        {
            heading => 'y',
            x => $botspot->{targetPos}->{x},
            y => $botspot->{targetPos}->{y} + $diffY * $step
        };
    }
}

sub parseChat
{
    my($hook, $args) = @_;
    my $user = $args->{MsgUser};
    my $message = $args->{Msg};
        
    if($message =~ m/^Arrived at ([0-9]+), ([0-9]+)$/)
    {
        my $arrived = {x => $1, y => $2};
    
        if($user eq $botspot->{priest})
        {
            if($step->{priest} == 1)
            {
                my $distance = distance($botspot->{targetPos}, $arrived);
            
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
            elsif($step->{priest} == 2)
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
                    $step->{priest}++;
                    
                    # Wait a second so our priest can cast warp portal
                    sleep(1);
                    
                    # Start the freeze
                    freeze();
                }
            }
        }
        elsif($user eq $botspot->{wizard})
        {
            # Check to make sure we actually ended up in a straight line relative to the spammer
            # Also make sure we're not on the warp cell
            if((($botspot->{heading} eq 'x' and $botspot->{targetPos}->{y} == $arrived->{y}) or
                ($botspot->{heading} eq 'y' and $botspot->{targetPos}->{x} == $arrived->{x})) and
                ($arrived->{x} != $botspot->{warpPos}->{x} and $arrived->{y} != $botspot->{warpPos}->{y}))
            {
                Commands::run("pm '$botspot->{wizard}' ice wall '$botspot->{target}->{name}' please");
            }
            
            # Otherwise let's try moving again, but increase the step
            else
            {
                $step->{wizard}++;
            
                my $newPos = straightPos($botspot->{targetPos}, $botspot->{warpPos}, $step->{wizard});
                Commands::run("pm '$botspot->{wizard}' exec move $newPos->{x} $newPos->{y}");
            }
            
            print("Oh what a happy day!\n");
            #Commands::run("pm '$botspot->{knight}' move '$arrived->{x}' '$arrived->{y}'");
        }
        elsif($user eq $botspot->{knight})
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
        $botspot->{targetPos} = $pos;
      
        print("Player '$player->{name}' matched at $pos->{x}, $pos->{y}\n");
      
        # Reset steps in case this isn't the first dunk
        $step = {'priest' => 1, 'wizard' => 1, 'knight' => 1};        
        
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
    # Move our wizard in a straight line relative to the spammer
    my $newPos = straightPos($botspot->{targetPos}, $botspot->{warpPos});
    $botspot->{heading} = $newPos->{heading};
    
    # This method does not account for... anything really.
    # Colin fix it.    
    
    Commands::run("pm '$botspot->{wizard}' exec move $newPos->{x} $newPos->{y}");
}

sub dunk
{
    
}

1;