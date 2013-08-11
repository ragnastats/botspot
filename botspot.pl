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
                'knight'	=> 'A Little Nudge',
                'dancer'    => 'Hip Shaker',
                'bard'      => 'Unbarring Octave'};
                
my $step = {'priest' => 1, 'wizard' => 1, 'knight' => 1};

my $position = {};

Commands::register(["dunk", "Gonna get dunked", \&start]);
Plugins::register("Botspot", "Dunk them spammers", \&unload);

my $hooks = Plugins::addHooks(['mainLoop_post', \&loop],
                                ["packet_privMsg", \&parseChat],
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
        'x' => int(rand(3)) + 1,
        'y' => int(rand(3)) + 1
    };
    
    if(int(rand(3))) {
        $offset->{x} *= -1;
    }
    if(int(rand(3))) {
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

sub loop
{
    my $time = time();

    # Wait for the warp portal to close before closing the chats
    if($botspot->{chatOpened} and $time > $botspot->{chatOpened} + 16)
    {
        Commands::run("p exec chat leave");
        
        # Amp
        Commands::run("p exec ss 304");
        delete($botspot->{chatOpened});
        Plugins::callHook('dunk', {status => 'success'});
    }
}

sub parseChat
{
    my($hook, $args) = @_;
    my $user = $args->{MsgUser};
    my $message = $args->{Msg};
        
    # Grab coordinates from arrival messages, but only if we have a target
    if($message =~ m/^Arrived at ([0-9]+), ([0-9]+)$/ and $botspot->{target})
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
                    Commands::run("p $botspot->{priest} exec move $random->{x} $random->{y}");

                    $botspot->{warpPos} = {x => $arrived->{x}, y =>$arrived->{y}};
                    $step->{priest} += 1
                }
                
                # The spammer is surrounded by people and can't be warped easily :(
                else
                {
                    print("We can't dunk this man. He is undunkable.\n");
                    Plugins::callHook('dunk', {status => 'failure'});
                }
            } 
            elsif($step->{priest} == 2)
            {
                # We tried to move randomly, but did we actually move off the warp position?
                if($arrived->{x} == $botspot->{warpPos}->{x} and $arrived->{y} == $botspot->{warpPos}->{y})
                {
                    my $random = randomPos($arrived);
                    Commands::run("p $botspot->{priest} exec move $random->{x} $random->{y}");
                }
                
                # If so, cast warp!
                else
                {
                    # Only use level 2 warp portal, since it closes faster
                    Commands::run("p $botspot->{priest} exec sl 27 $botspot->{warpPos}->{x} $botspot->{warpPos}->{y} 2");
					#Commands::run("p $botspot->{priest} exec c S-Sorry... I'm going to have to ask you to leave...");
                    $step->{priest}++;

                    # Move our dance team into position
                    $position->{priest} = $arrived;
                    dance();
                }
            }
        }
        elsif($user eq $botspot->{dancer})
        {
            # Move our bard next
            $position->{dancer} = $arrived;
            strum();
        }
        elsif($user eq $botspot->{bard})
        {
            # TODO: Make sure the bard and dancer are actually 1 cell apart
            Commands::run("p exec ss 312");
            
            # Start the freeze
            $position->{bard} = $arrived;
            freeze();
        }
        elsif($user eq $botspot->{wizard})
        {
            # Check to make sure we actually ended up in a straight line relative to the spammer
            # Also make sure we're not on the warp cell
            if((($botspot->{heading} eq 'x' and $botspot->{targetPos}->{y} == $arrived->{y}) or
                ($botspot->{heading} eq 'y' and $botspot->{targetPos}->{x} == $arrived->{x})) and
                !($arrived->{x} == $botspot->{warpPos}->{x} and $arrived->{y} == $botspot->{warpPos}->{y}))
            {
                # Summon our Knight before casting ice wall
                nudge();
            }
            
            # Otherwise let's try moving again, but increase the step
            else
            {            
                # If our step is positive, increment it and multiply by -1 to walk to the other side
                if($step->{wizard} > 0)
                {
                    $step->{wizard}++;
                    $step->{wizard} *= -1;
                }
                
                # If our step is negative, multiply it by -1 to walk to the other side but don't increase the step
                else
                {
                    $step->{wizard} *= -1;
                }
            
                my $newPos = straightPos($botspot->{targetPos}, $botspot->{warpPos}, $step->{wizard});
            
                if($newPos)
                {
                    Commands::run("p $botspot->{wizard} exec move $newPos->{x} $newPos->{y}");
                }
            }            
        }
        elsif($user eq $botspot->{knight})
        {
            # TODO: Maybe we should check to ensure the knight is actually on the warpPos?
            if($step->{knight} == 1)
            {
                # Once the knight arrives: cast ice wall!
                Commands::run("p $botspot->{wizard} exec sp 87 '$botspot->{target}->{name}'");
				#Commands::run("p $botspot->{wizard} exec c Haha! Eat ice, jerkbag!");
                sleep(1);
                Commands::run("p $botspot->{knight} exec look  " . aboutFace());
                sleep(1);
                Commands::run("p $botspot->{knight} exec sp 62 '$botspot->{target}->{name}' 1");
				#Commands::run("p $botspot->{knight} exec c Get dunked!!");
                sleep(1);
                Commands::run('p exec chat create "GET DUNKED FOOL"');
                $botspot->{chatOpened} = time();
                dunk();
#                my $random = randomPos($arrived);
#                Commands::run("p $botspot->{knight} exec move $random->{x} $random->{y}");
                
#                $step->{knight}++;
            }
#            elsif($step->{knight} == 2)
#            {
                # We tried to move randomly, but did we actually move off the warp position?
#                if($arrived->{x} == $botspot->{warpPos}->{x} and $arrived->{y} == $botspot->{warpPos}->{y})
#                {
#                    my $random = randomPos($arrived);
#                    Commands::run("p $botspot->{knight} exec move $random->{x} $random->{y}");
#                }
                
                # If so, DUNK THAT JERK
#                else
#                {
#                    $step->{knight}++;
#                    dunk();
#                }
#            }
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
        
         # Sanitize usernames by adding slashes
        $botspot->{target}->{name} =~ s/'/\\'/g;
        $botspot->{target}->{name} =~ s/;/\\;/g;
        
        print("Player '$player->{name}' matched at $pos->{x}, $pos->{y}\n");
      
        # Reset steps in case this isn't the first dunk
        $step = {'priest' => 1, 'wizard' => 1, 'knight' => 1};        
        
        # Clear any previous warp commands
        Commands::run("p $botspot->{priest} exec warp cancel");

        # Use amp
        Commands::run("p exec ss 304");
        
        # Tell our priest to walk on top of the spammer
        Commands::run("p $botspot->{priest} exec move $pos->{x} $pos->{y}");
    }
    else
    {
        print("No players matched\n");
        Plugins::callHook('dunk', {status => 'not found'});
    }
}

sub dance
{    
    # Tell our dancer to walk on top of the priest
    Commands::run("p $botspot->{dancer} exec move $position->{priest}->{x} $position->{priest}->{y}");
}

sub strum
{   
    # Tell our bard to walk on top of the dancer
    Commands::run("p $botspot->{bard} exec move $position->{dancer}->{x} $position->{dancer}->{y}");
}

sub freeze
{
    # Move our wizard in a straight line relative to the spammer
    my $newPos = straightPos($botspot->{targetPos}, $botspot->{warpPos});

    if($newPos)
    {
        $botspot->{heading} = $newPos->{heading};
        
        # When the wizard moves, parseChat ensures the wizard moves in a straight line
        
        # TODO: Add a maximum number of steps before the wizard gives up
        # TODO: Once this maximum is reached, restart the script and try getting a different heading
        
        Commands::run("p $botspot->{wizard} exec move $newPos->{x} $newPos->{y}");
    }
}

sub nudge
{
    # Move our knight to the warp position
    Commands::run("p $botspot->{knight} exec move $botspot->{warpPos}->{x} $botspot->{warpPos}->{y}");
}

sub dunk
{
    # Bye bye spammer!
    Commands::run("p $botspot->{priest} exec warp 1");
	#Commands::run("p $botspot->{priest} exec c I'm really sorry about this!");
}

sub aboutFace
{    if($botspot->{targetPos}->{x} == $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} < $botspot->{warpPos}->{y})
     {
        return 0
     }
     elsif($botspot->{targetPos}->{x} > $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} < $botspot->{warpPos}->{y})
     {
        return 1
     }
     elsif($botspot->{targetPos}->{x} > $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} == $botspot->{warpPos}->{y})
     {
        return 2
     }
     elsif($botspot->{targetPos}->{x} > $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} > $botspot->{warpPos}->{y})
     {
        return 3
     }
     elsif($botspot->{targetPos}->{x} == $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} > $botspot->{warpPos}->{y})
     {
         return 4
     }
     elsif($botspot->{targetPos}->{x} < $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} > $botspot->{warpPos}->{y})
     {
        return 5
     }
     elsif($botspot->{targetPos}->{x} < $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} == $botspot->{warpPos}->{y})
     {
        return 6
     }
     elsif($botspot->{targetPos}->{x} < $botspot->{warpPos}->{x} && $botspot->{targetPos}->{y} < $botspot->{warpPos}->{y})
     {
        return 7
     }
     
}

1;