#
#   Hey!
#     Listen!
#
# This plugin requires OpenKore revision 7970 or later.
#
#######################################################

package Ignore;

# Perl includes
use strict;
use Storable;
use Data::Dumper;
use Time::HiRes qw(time);

# Kore includes
use Settings;
use Plugins;
use Network;
use Globals;
use Utils;



our $spam = {};
our $dunk ||= {'replay' => 1};


Commands::register(["reset", "Reset spammer timeout", \&reset]);
Commands::register(["spammers", "Ignore debug info", \&debug]);
Plugins::register("Ignore Spammers!", "Version 0.1 r3", \&unload);
my $hooks = Plugins::addHooks(['mainLoop_post', \&loop],
								['packet_pre/public_chat', \&parseChat],
								['packet_pre/actor_display', \&parseActor],
								['dunk', \&parseDunk]);

								
sub unload
{
	Plugins::delHooks($hooks);
}

sub debug
{
	print("Time: ".time()."\n");
	print("Queue: ".@{$dunk->{queue}}."\n");
	print(Dumper($dunk));
}

sub reset
{
	$dunk->{timeout} = time();
}

sub loop
{
	if($config{botspot_admin})
	{
		my $time = time();

		if(!$dunk->{target} and $dunk->{reload} and $dunk->{reload} + 10 < $time)
		{
			Commands::run("plugin reload all");
			delete($dunk->{reload});
		}
		
		if(scalar keys %{$spam->{queue}})
		{
			while(my($userID, $queue) = each(%{$spam->{queue}}))
			{
				# Spam total too high! Spammer ignored!
				if($spam->{$userID}->{total} > 33)
				{
					#Commands::run("conf route_randomWalk 0");
					$dunk->{replay} = 0;
					Commands::run("replay stop");
					Commands::run("move stop");
					$dunk->{timeout} = time() + 3;
					
					if($config{spammer_silence})
					{
						$net->clientSend($packetParser->reconstruct({
											switch => 'character_status',
											ID => $userID,
											opt1 => 0,
											opt2 => 4,
											option => 0,
											stance => 0
										}));
					}
					
					$spam->{$userID}->{ignored} = 1;
					delete($spam->{queue}->{$userID});                
					push(@{$dunk->{queue}}, $userID);
				}
				else
				{
					# Oops, they must not be a spammer
					if($queue->{timeout} < $time)
					{
						foreach my $queueArgs (@{$queue->{messages}})
						{
							my $actor = Actor::get($queueArgs->{ID});
							my $dist = Utils::distance($char->{pos_to}, $actor->{pos_to});
					
							# You can only see chat messages within 13 cells.
							if($config{XKore} > 0 and $dist < 13)
							{
								$net->clientSend($packetParser->reconstruct({
									switch => 'public_chat',
									ID => $queueArgs->{ID},
									message => $queueArgs->{message},
								}));
							}
						}
						
						delete($spam->{queue}->{$userID});
					}
				}	
			}	
		}
		
		if((!$dunk->{queue} or $dunk->{queue} and @{$dunk->{queue}} == 0) and $dunk->{replay} == 0 and $time > $dunk->{timeout} + 10)
		{
			$dunk->{reload} = time();
			#Commands::run("conf route_randomWalk 1");
			$dunk->{replay} = 1;
			Commands::run("replay start");
			Commands::run("p exec follow $char->{name}");
            Commands::run("follow stop");
		}
		
		if($dunk->{queue} and @{$dunk->{queue}} and $time > $dunk->{timeout})
		{
			if(($dunk->{target} and $time > $dunk->{timeout} + 60) or (!$dunk->{target} and $time > $dunk->{timeout}))
			{
				print("Dunk timeout reached, getting new target\n");
				print("Timeout: $dunk->{timeout}\n");
				print("Time:    $time\n");
				
				$dunk->{target} = shift(@{$dunk->{queue}});
				$dunk->{timeout} = time() + 60;

				print(Dumper($dunk));
				
				if($dunk->{target})
				{
					my $actor = Actor::get($dunk->{target});
					
					print(Dumper($actor));
					print("Spammer? $actor->{name}\n");
					
					my $spammer =  $actor->{name};
					$spammer =~ s/;/\\;/g;
					
					if($spammer)
					{
                        my $pos = calcPosition($actor);
                        
                        # Only start dunking if they're not moving
                        if($pos->{x} == $actor->{pos_to}->{x} and
                            $pos->{y} == $actor->{pos_to}->{y})
                        {
                            Commands::run("p exec follow stop");
        #                    Commands::run("p exec plugin reload all");

                            print("Spammer? $spammer \n");
                            
                            Commands::run("dunk $spammer");
                        }
                        else
                        {
                            print("Calc\n");
                            print(Dumper());
                            print("Pos\n");
                            print(Dumper($actor->{pos}));
                            print("Pos to\n");
                            print(Dumper($actor->{pos_to}));
                            if($dunk->{tries} > 20)
                            {
                                # Give up
                                delete($dunk->{target});
                                $dunk->{timeout} = time();
                            }
                            else
                            {
                                # Try again
                                unshift(@{$dunk->{queue}}, $dunk->{target});
                                delete($dunk->{target});
                                $dunk->{timeout} = time() + 0.5; # Try once a second
                                $dunk->{tries}++;
                            }
                        }
					}
					else
					{
						if($dunk->{tries} > 3)
						{
							# Give up
							delete($dunk->{target});
							$dunk->{timeout} = time();
						}
						else
						{
							# Try again
							unshift(@{$dunk->{queue}}, $dunk->{target});
							delete($dunk->{target});
							$dunk->{timeout} = time();
							$dunk->{tries}++;
						}
					}
				}
			}
		}
	}
}

sub parseDunk
{
	if($config{botspot_admin})
	{
		my($hook, $args) = @_;
		
		if($args->{status} eq 'success')
		{
			delete($dunk->{target});
			$dunk->{timeout} = time();   
			$dunk->{tries} = 0;
			
			unless($dunk->{queue} and @{$dunk->{queue}})
			{
				$dunk->{reload} = time();
				#Commands::run("conf route_randomWalk 1");
				$dunk->{replay} = 1;
				Commands::run("replay start");
				Commands::run("p exec follow $char->{name}");
                Commands::run("follow stop");
			}
			else
			{
				print(Dumper($dunk->{queue}));
			}
		}
		elsif($args->{status} eq 'failure')
		{
			if($dunk->{tries} > 3)
			{
				# Give up
				delete($dunk->{target});
				$dunk->{timeout} = time();
			}
			else
			{
				# Try again
				unshift(@{$dunk->{queue}}, $dunk->{target});
				delete($dunk->{target});
				$dunk->{timeout} = time();
				$dunk->{tries}++;
			}
		}
		elsif($args->{status} eq 'not found')
		{
			delete($dunk->{target});
			$dunk->{timeout} = time();
			$dunk->{tries} = 0;
		}
	}
}

sub parseChat
{
	if($config{botspot_admin})
	{
		my($hook, $args) = @_;
		my $chat = Storable::dclone($args);

		if($spam->{$args->{ID}}->{ignored}) {
			$args->{return} = 1;
			$args->{mangle} = 2;		
		}
		
		# If someone has a total score less than -24 there's almost no chance they're a spammer.
		elsif($spam->{$args->{ID}}->{total} > -24)
		{
			my $actor = Actor::get($args->{ID});
			my $time = time();
			my $spamScore;

		
			# Spam bots are usually low level.
			if($actor->{lv} < 25) {
				$spamScore++;
			}
			else {
				$spamScore -= 3;
			}
			
			# Spam bots usually have default hair.
			if($actor->{hair_style} == 1) {
				$spamScore++;
			}
			
			if($actor->{hair_color} == 0) {
				$spamScore++;
			}
			
			# Spam bots are usually novices.
			if($actor->{jobID} == 0) {
				$spamScore++;
			}
			
			# Ever seen a spam bot in a guild? Me neither.
			if(unpack('V', $actor->{guildID}) == 0) {
				$spamScore++;
			}
			else {
				$spamScore -= 5;
			}
			
			# Strip characters used as spacers.
			$chat->{message} =~ s/[ `'"\[\]\(\)~;\|]//g;
			
			# Generic spam messages.
			$spamScore++ while($chat->{message} =~ /==|__|3w|vvv?|www|com|c0m|net|0rg|org|selling|zeny|faster|cheaper|instant|mmook|irozenyshop|bonus|bonvs|safe|150m|200m|100m|usd|goldcentral|irozenyshop|arozeny|gridgold|buyrozeny|buyr0zeny|buyr0zeny|buyr0zeny|wait/ig);
			
			print("$spamScore - $chat->{message}\n");
			
			# How many messages were sent from this user in the last 3 seconds?
			if($spam->{$args->{ID}}->{lastMessage} + 3 > $time)
			{
				$spam->{$args->{ID}}->{consecutively}++;
				
				$spamScore += $spam->{$args->{ID}}->{consecutively};
			}
			else {
				$spam->{$args->{ID}}->{consecutively} = 0;
			}
			
			$spam->{$args->{ID}}->{lastMessage} = $time;
			
			# This might be spam!
			if($spamScore > 5)
			{
				#Commands::run("conf route_randomWalk 0");
				$dunk->{replay} = 0;
				Commands::run("replay stop");
				Commands::run("move stop");
				$dunk->{timeout} = time() + 90;
                Commands::run("follow $actor->{name}");
		
				$args->{return} = 1;
				$args->{mangle} = 2;
			
				$spam->{queue}->{$args->{ID}}->{timeout} = $time + 3;
				push(@{$spam->{queue}->{$args->{ID}}->{messages}}, $args);
			}

			$spam->{$args->{ID}}->{total} += $spamScore;		
		}
	}
}

sub parseActor
{
	if($config{botspot_admin})
	{
		$config{spammer_hide}		||= 0;
		$config{spammer_silence}	||= 1;

		my($hook, $args) = @_;

        
#        if($args->{lv} == 1 and $args->{name} ne "Little Poring" and $args->{manner} == 0 and $config{follow} == 0)
#        {
#            print("Level 1? Looks suspicious...\n");
#            $dunk->{replay} = 0;
#            Commands::run("replay stop");
#            Commands::run("move stop");
#            Commands::run("follow $args->{name}");
#            $dunk->{timeout} = time() + 30;
#
#            print(Dumper($args));
#        }
		
		if($spam->{$args->{ID}}->{ignored})
		{
			my $actor = Actor::get($args->{ID});
		
			# Don't try to dunk someone if they're moving
			if($actor->{pos}->{x} == $actor->{pos_to}->{x} and
				$actor->{pos}->{y} == $actor->{pos_to}->{y})
			{
				push(@{$dunk->{queue}}, $args->{ID});
	#            Commands::run("conf route_randomWalk 0");
				$dunk->{replay} = 0;
				Commands::run("replay stop");
				Commands::run("move stop");
                Commands::run("follow $actor->{name}");
				$dunk->{timeout} = time() + 3;
			}
			
			if($config{spammer_hide})
			{
				$args->{return} = 1;
				$args->{mangle} = 2;
			}
			
			if($config{spammer_silence})
			{
				$args->{manner} = 65535;
				$args->{mangle} = 1;
			}
		}
	}
}

1;
