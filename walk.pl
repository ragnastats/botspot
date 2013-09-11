package Walk;


# Perl includes
use strict;

# Kore includes
use Settings;
use Plugins;
use Network;
use Globals;
use Utils;
use Data::Dumper;

our $record ||= {route => []};
our $replay ||= {route => []};

Commands::register(["record", "Start recording route", \&record]);
Commands::register(["replay", "Start replaying route", \&replay]);

# Record route to replay later
sub record
{
    my($command, $arg) = @_;

    if($arg eq 'start')
    {
        $record->{status} = 1;
    }
    elsif($arg eq 'stop')
    {
        $record->{status} = 0;
    }
    elsif($arg eq 'save')
    {
        $replay->{route} = $record->{route};
    }
    elsif($arg eq 'log')
    {
        print(Dumper($record->{route}));
    }
    elsif($arg eq 'clear')
    {
        $record->{route} = [];
    }
}

sub replay
{
   my($command, $arg) = @_;

    if($arg eq 'start')
    {
        if(@{$replay->{route}})
        {
            $replay->{status} = 1;
        }
    }
    elsif($arg eq 'stop')
    {
        $replay->{status} = 0;
    }
}

sub randomPos
{
    my($pos) = @_;
    
    my $offset = {
        'x' => int(rand(3)),
        'y' => int(rand(3))
    };
    
    if(int(rand(1))) {
        $offset->{x} *= -1;
    }
    if(int(rand(1))) {
        $offset->{y} *= -1;
    }

    return {x => $offset->{x} + $pos->{x},
            y => $offset->{y} + $pos->{y}};    
}

Plugins::register("Walk", "All Around Town", \&unload);
my $hooks = Plugins::addHooks(['mainLoop_post', \&loop]);

								
sub unload
{
	Plugins::delHooks($hooks);
}

sub loop
{
    my $time = time();

    if($record->{status} and $record->{timeout} < $time)
    {
        $record->{timeout} = $time + 1;
        my $pos = calcPosition($char);
    
        push(@{$record->{route}}, "move $pos->{x} $pos->{y}");
        print("Recording: $pos->{x}, $pos->{y}\n");        
    }
    
    if($replay->{status} and $replay->{timeout} < $time)
    {
        $replay->{timeout} = $time + 1;
        my $commandString = shift(@{$replay->{route}});
		my @command = split(/ /, $commandString);
		
		if($command[0] eq 'move')
		{
			my $random = randomPos({x => $command[1], y => $command[2]});
			Commands::run("move $random->{x} $random->{y}");
		}		
		else
		{
			Commands::run($commandString);
        }
		
        push(@{$replay->{route}}, $commandString);
        print("Replaying: $commandString\n");
    }
}

1;