#!/usr/bin/perl
use strict;
use warnings;

my $help = 0;
my $directed = 0;
my $weighted = 0;
my $operonInput = 0;
my $inputFile = "";
my $gephi = 0;
my $outputFile = "";
my @globalInput;

my @map;
my %weightMap;
my @transcribingGenes;
my %operonMap;
my @adjacency;
main();

sub main {
	readCLInput();
	readInputFile();
	createMaps();
	createAdjacency();
	createConfigurationFile();
	my $codeOutput = runCode();
	my $parsedOutput_ref = parseCodeOutput($codeOutput);
	my %groupoids = formGroupoids($parsedOutput_ref);
	createOutput(%groupoids);
	createGephiOutput($parsedOutput_ref);
}

sub readCLInput {
	while (my $arg = shift @ARGV) {
		if($arg eq "-help") {
			$help = 1;
			last;
		}
		if($arg eq "-directed") {
			$directed = 1;
			next;
		}
		if($arg eq "-weighted") {
			$weighted = 1;
			next;
		}
		if($arg eq "-gephi") {
			$gephi = 1;
			next;
		}
		if($arg eq "-operon") {
			$operonInput = 1;
			$weighted = 1;
			$directed = 1;
			next;
		}
		if($arg eq "-inputFrom") {
			$inputFile = shift @ARGV;
			next;
		}
		if($arg eq "-outputTo") {
			$outputFile = shift @ARGV;
			next;
		}
		$help = 1;
	}

	if ($help == 1) {
		print("Usage:\n");
		print("./run.pl -\$keys\n");
		print("Possible keys:\n");
		print("-help\t\t\t- Prints this help message with usage\n");
		print("-directed\t\t- Initially we think that graph is undirected, sets it to directed\n");
		print("-weighted\t\t- Initially we think that graph is unweighted, sets it to weighted\n");
		print("-gephi\t\t\t- Create output in a gephi format. Uses outputTo file directory. If not specified, puts it together with the code\n");
		print("-operon\t\t\t- Using input from regulonDB operons. Initializes weighed and directed itself\n");
		print("-inputFrom filename\t- Path to file with connections to setup adjacency\n");
		print("-outputTo filename\t- Path to output file\n");
		exit;
	}

	print("Printing insterted parameters for script to run...\n");
	print("help\t\t= $help\n");
	print("directed\t= $directed\n");
	print("weighted\t= $weighted\n");
	print("gephi\t\t= $gephi\n");
	print("operon\t\t= $operonInput\n");
	print("inputFile\t= $inputFile\n");
	print("outputFile\t= $outputFile\n");
}

sub readInputFile {
	if($inputFile eq "") {
		print("No input file path\n");
		print("Try using \"-help\" key for usage\n");
		exit;
	}
	local $/=undef;
	open(FID, $inputFile)
		or die "Failed to open $inputFile: $!\n";
	my $input = <FID>;
	close(FID);
	$input = lc($input);
	@globalInput = split(/\n/, $input);

	@globalInput = grep { $_ ne "" } @globalInput;

	#print input
	print("Printing input file.\n");
	foreach my $line (@globalInput) {
		print("$line\n");
	}

	return;
}

sub createMaps {
	print("Creating map\n");
	my @tmpInput = @globalInput;
	foreach my $line (@tmpInput) {
		my $tmp1;
		my $tmp2;
		my $tmp3;
		if($operonInput == 0) {
			if($weighted == 0) {
				$line =~ s/(\S+)\s+(\S+)\s*//;
				$tmp1 = $1;
				$tmp2 = $2;
			} else {
				$line =~ s/(\S+)\s+(\S+)\s+(\S+)\s*//;
				$tmp1 = $1;
				$tmp2 = $2;
				$tmp3 = $3;
			}
		} else {
			$line =~ s/^(\S+)\s+([\S\s]+)\[([\s\S]+)\]\s+([+-?]{1,2})([\S\s]+)$//;
			my $transcribingGene = $1;
			my $operon = $2;
			my @genes = split /, /, $3;
			my $weight = $4;
			$tmp1 = $transcribingGene;
			$tmp2 = $operon;
			$tmp3 = $weight;
			if(!grep{$_ =~ /^$transcribingGene$/} @transcribingGenes) {
				push @transcribingGenes, $transcribingGene;
			}
			# if operon consists of more, then one gene, we want to add it to operon map
			if((scalar @genes > 1) and !(exists $operonMap{$operon})) {
				foreach my $gene (@genes) {
					push(@{$operonMap{$operon}}, $gene);
				}
			}
		}

		if(!grep{$_ =~ /^$tmp1$/} @map) {
			push @map, $tmp1;
		}
		if(!grep{$_ =~ /^$tmp2$/} @map) {
			push @map, $tmp2;
		}
		if($weighted == 1 and !exists $weightMap{$tmp3}) {
			$weightMap{$tmp3} = keys %weightMap;
		}
	}
	@map = sort values @map;

	#print maps
	print("Printing map of all possible nodes...\n");
	my $i = 0;
	foreach my $entry (@map) {
		print("$i\t- \"$entry\"\n");
		$i++;
	}
	print("Printing map of all possible weights...\n");
	foreach my $entry (keys %weightMap) {
		print("$weightMap{$entry}\t - $entry\n");
	}
	print("Printing map of all operons...\n");
	foreach my $operon (sort keys %operonMap) {
		print("$operon:\t");
		my $numberOfGenes = @{$operonMap{$operon}};
		for(my $i = 0; $i < $numberOfGenes; $i++) {
			print("$operonMap{$operon}[$i], ");
		}
		print("\n");
	}
	print("Printing map of transcribing genes...\n");
	for(my $i = 0; $i < scalar @transcribingGenes; $i++) {
		print("$transcribingGenes[$i]\n");
	}
	return;
}

sub createAdjacency {
	my @tmpInput = @globalInput;

	my $lineNumber = 0;
	foreach my $line (@tmpInput) {
		my $source;
		my $destination;
		my $weight;
		if($operonInput == 0) {
			if($weighted == 1) {
				$line =~ s/(\S+)\s+(\S+)\s+(\S+)\s*//;
				$source = $1;
				$destination = $2;
				$weight = $3;
			} else {
				$line =~ s/(\S+)\s+(\S+)\s*//;
				$source = $1;
				$destination = $2;
			}
		} else {
			$line =~ s/^(\S+)\s+([\S\s]+)\[([\s\S]+)\]\s+([+-?]{1,2})([\S\s]+)$//;
			$source = $1;
			$destination = $2;
			$weight = $4;
		}

		my $pos;
		($pos) = grep{ $map[$_] =~ m/^$source$/} 0 .. $#map;
		$adjacency[$lineNumber][0] = $pos;
		($pos) = grep{ $map[$_] =~ m/^$destination$/} 0 .. $#map;
		$adjacency[$lineNumber][1] = $pos;
		if($weighted == 1) {
			$adjacency[$lineNumber][2] = $weightMap{$weight};
		}
		$lineNumber++;
	}


	print("Printing adjacency matrix...\n");
	if($weighted == 0) {
		for(my $i = 0; $i < $lineNumber; $i++) {
			print("$adjacency[$i][0]\t$adjacency[$i][1]\n");
		}
	} else {
		for(my $i = 0; $i < $lineNumber; $i++) {
			print("$adjacency[$i][0]\t$adjacency[$i][1]\t$adjacency[$i][2]\n");
		}
	}

	return;
}

sub createConfigurationFile {
	my $numberOfNodes = scalar @map;
	my $numberOfWeights = scalar %weightMap;
	my $numberOfConnections = scalar @adjacency;
	my $secondSize = @{$adjacency[0]};
	# adjacency.txt structure
	# 1: size in cells
	# 2: directed/undirected
	# 3: weighted/not weighted
	# 4: number of weights
	# 5..inf: adjacency matrix
	open (adjacencyFile, '>', "adjacency.txt");
	print adjacencyFile $numberOfNodes;
	print adjacencyFile "\n$directed\n";
	print adjacencyFile "$weighted\n";
	print adjacencyFile "$numberOfWeights\n";
	for(my $i = 0; $i < $numberOfConnections; $i++) {
			for(my $j = 0; $j < $secondSize; $j++) {
					print adjacencyFile "$adjacency[$i][$j]\t";
			}
			print adjacencyFile "\n";
	}
	close (adjacencyFile); 
	return;
}

sub runCode {
	print("Compiling code\n");
	system("g++ -std=c++11 ./grcode.cpp -o grcode");
	# TODO: check if there are no "   " instead of '\t' symbol, cause it will cause problems
	print("Running code\n");
	my $start = time;
	my $codeOutput = qx("./grcode");
	my $duration = time - $start;
	print "Execution time: $duration s\n";
	# TODO: check if code actually gave positive result
	return $codeOutput;
}

sub parseCodeOutput {
	print("Parsing code output...\n");
	my ($codeOutput) = @_;
	my @output = ();
	my @data = split /\n/, $codeOutput;
	my $i = 0;
	foreach(@data) {
		my @tmp = split /\t/, $_;
		$output[$i][0] = $tmp[0];
		$output[$i++][1] = $tmp[1];
	}

	return \@output;
}

sub formGroupoids {
	my ($parsedOutput_ref) = @_;
	my @parsedOutput = @$parsedOutput_ref;
	my %groupoids;

	for(my $i = 0; $i < scalar @parsedOutput; $i++) {
		push(@{$groupoids{$parsedOutput[$i][1]}}, $map[$parsedOutput[$i][0]]);
	}
	return %groupoids;
}

sub createOutput {
	my %groupoids = @_;
	my $numberOfGroupoids = keys %groupoids;
	print("Printing parsed code output...\n");
	for(my $i = 0; $i < $numberOfGroupoids; $i++) {
		print("$i:\t");
		for(my $j = 0; $j < scalar @{$groupoids{$i}}; $j++) {
			print("$groupoids{$i}[$j]\t");
		}
		print("\n");
	}
	if($outputFile ne "") {
		open (outputFile, '>', $outputFile);
		for(my $i = 0; $i < $numberOfGroupoids; $i++) {
			print(outputFile "$i:\t");
			for(my $j = 0; $j < scalar @{$groupoids{$i}}; $j++) {
				print(outputFile "$groupoids{$i}[$j]\t");
			}
			print(outputFile "\n");
		}
		close(outputFile);
	}
}

sub createGephiOutput {
	my ($parsedOutput_ref) = @_;
	my @parsedOutput = @$parsedOutput_ref;
	
	my $gephiOutputFile;
	if($outputFile ne "") {
		$gephiOutputFile = $outputFile;
		$gephiOutputFile =~ s/\.[\w\W]+$//;
	} else {
		$gephiOutputFile = "gephi";
	}

	open (nodesFile, '>', $gephiOutputFile . "_nodes.csv");
	print(nodesFile "Id,Label,modularity_class\n");
	for(my $i = 0; $i < scalar @map; $i++) {
		print(nodesFile "$i,$map[$i],$parsedOutput[$i][1]\n");
	}
	close(nodesFile);

	open (edgesFile, '>', $gephiOutputFile . "_edges.csv");
	print(edgesFile "Source,Target,Type");
	if($weighted) {print(edgesFile ",Weight\n");}
	else {print(edgesFile "\n");}
	my $type;
	if($directed) {$type = "directed";}
	else {$type = "undirected";}
	for(my $i = 0; $i < scalar @adjacency; $i++) {
		print(edgesFile "$adjacency[$i][0],$adjacency[$i][1],$type");
		if($weighted) {
			#we add 1 here, because gephi doesn't like when weight is equal to 0
			my $gephiWeight = $adjacency[$i][2] + 1;
			print(edgesFile ",$gephiWeight");
		}
		print(edgesFile "\n");
	}
	close(edgesFile);
}
