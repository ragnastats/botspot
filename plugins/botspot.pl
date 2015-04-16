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
use Log qw(message warning error debug);


my $botspot = {'priest'		=> 'Warp Drive Active',
                'wizard'	=> 'Chilling Effects',
                'knight'	=> 'A Little Nudge',
                'dancer'    => 'Faye Romani',
                'bard'      => 'One Man Band'};
                
my $step = {'priest' => 1, 'wizard' => 1, 'knight' => 1};

my $ready = {};
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
        'x' => int(rand(3) + 0.5) + 3,
        'y' => int(rand(3) + 0.5) + 3
    };
    
    if(int(rand(1) + 0.5))
    {
        $offset->{x} *= -1;
    }
    
    if(int(rand(1) + 0.5))
    {
        $offset->{y} *= -1;
    }

    return {x => $offset->{x} + $pos->{x},
            y => $offset->{y} + $pos->{y}};    
}

# Accepts two position hashes and returns a new hash in a straight line and the relative heading
sub straightPos
{
    my($pos1, $pos2, $step) = @_;
    $step ||= -1;
    
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

    # We ready? LET'S GO
    if($ready->{wizard} and $ready->{knight})
    {
        # Power cord!
        Commands::run("p $botspot->{dancer} exec ss 312");
        # Ice wall!
        Commands::run("p $botspot->{wizard} exec sl 87 $botspot->{targetPos}->{x} $botspot->{targetPos}->{y}");
        # Line up the shot...
        Commands::run("p $botspot->{knight} exec look  " . aboutFace());
        sleep(0.5);
        # Bowling bash!
        Commands::run("p $botspot->{knight} exec sp 62 '$botspot->{target}->{name}' 1");
        dunk();
        sleep(1);
        Commands::run('p exec chat create "GET DUNKED FOOL"');

        # Run north incase you can't create chats
        # TODO: Run in the direction the ice wall isn't
        Commands::run("p $botspot->{knight} exec north 5");

        Commands::run("p exec follow $char->{name}");

        $botspot->{chatOpened} = time();

        $ready = {};
    }

    # Wait for the warp portal to close before closing the chats
    if($botspot->{chatOpened} and $time > $botspot->{chatOpened} + 15)
    {
        Commands::run("p exec chat leave");
        sleep(1);
        
        # Amp
        Commands::run("p $botspot->{dancer} exec ss 304");
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

                    Commands::run("p $botspot->{dancer} exec follow $botspot->{priest}");
                    Commands::run("p $botspot->{bard} exec follow $botspot->{dancer}");

                    # Sleep for a second after casting portal
                    sleep(1);

                    # Move the wizard and knight into position at the same time
                    freeze();
                    nudge();
                    #dance();
                }
            }
        }
=pod
        elsif($user eq $botspot->{dancer})
        {
            # Move our bard next
            $position->{dancer} = $arrived;
            strum();
        }
        elsif($user eq $botspot->{bard})
        {
            # TODO: Make sure the bard and dancer are actually 1 cell apart
            # TODO: Make sure power cord was actually cast (temporary solution: give priest some bgems to use in case there's a problem)
            Commands::run("p $botspot->{dancer} exec ss 312");
            
            # Start the freeze
            $position->{bard} = $arrived;
            sleep(1);
            freeze();
        }
=cut
        elsif($user eq $botspot->{wizard})
        {
            # Check to make sure we actually ended up in a straight line relative to the spammer
            # Also make sure we're not on the warp cell
            if((($botspot->{heading} eq 'x' and $botspot->{targetPos}->{y} == $arrived->{y}) or
                ($botspot->{heading} eq 'y' and $botspot->{targetPos}->{x} == $arrived->{x})) and
                !($arrived->{x} == $botspot->{warpPos}->{x} and $arrived->{y} == $botspot->{warpPos}->{y}))
            {
                # Summon our Knight before casting ice wall
                #nudge();
                $ready->{wizard} = 1;
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
            $ready->{knight} = 1;

=pod
            if($step->{knight} == 1)
            {
                # Once the knight arrives: cast ice wall!
                Commands::run("p $botspot->{wizard} exec sl 87 $botspot->{targetPos}->{x} $botspot->{targetPos}->{y}");
               # sleep(1);
                Commands::run("p $botspot->{knight} exec look  " . aboutFace());
                sleep(0.5);
                Commands::run("p $botspot->{knight} exec sp 62 '$botspot->{target}->{name}' 1");
                dunk();
                sleep(1);
                Commands::run('p exec chat create "GET DUNKED FOOL"');

                # Run north incase you can't create chats
                # TODO: Run in the direction the ice wall isn't
                Commands::run("p $botspot->{knight} exec north 5");
                $botspot->{chatOpened} = time();

            }
=cut
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

        # Leave the chat, just in case
        Commands::run("p exec chat leave");

        # Stop following, just in case
        Commands::run("p exec follow stop");
        
        # Use amp
        Commands::run("p $botspot->{dancer} exec ss 304");
        
        # Tell our priest to walk on top of the spammer
        Commands::run("p $botspot->{priest} exec move $pos->{x} $pos->{y}");
    }
    else
    {
        print("No players matched\n");
        Plugins::callHook('dunk', {status => 'not found'});
    }
}

=pod
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
=cut

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
    my $target =
    {
        time    => time(),
        account => unpack('V', $botspot->{target}->{ID}),
        name => $botspot->{target}->{name},
        map     => $field->baseName(),
        x => $botspot->{targetPos}->{x},
        y => $botspot->{targetPos}->{y},
        job => $botspot->{target}->{jobID},
        level => $botspot->{target}->{lv},
        sex => $botspot->{target}->{sex},
        hair =>
        {
            style => $botspot->{target}->{hair_style},
            color => $botspot->{target}->{hair_color}
        }
    };

    $Data::Dumper::Terse = 1;        # Output less
    $Data::Dumper::Indent = 0;       # Don't output whitespace

    debug Dumper($target) . "\n", 'dunk_log', 1;

    # Bye bye spammer!
    Commands::run("p $botspot->{priest} exec warp 1");
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
