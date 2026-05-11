package mirror;

import sys.io.File;
import sys.FileSystem;

using StringTools;

class Mirror {
	private static final cache:Map<String, String> = new Map();
	private static final lineStartMatcher:EReg = ~/^\s*(?:\/\/ ?| \* )?/;
	private static final usage:String =
		"Usage: haxelib run mirror-check path/to/File1.hx path/to/File2.hx\n" +
 		"       haxelib run mirror-check path/to/File.hx --output path/to/OutputFile.hx\n" +
		"       haxelib run mirror-check path/to/File1.hx path/to/File2.hx --output MirroredFile1.hx\n";
	private static final wordMatcher:EReg = ~/\b[A-Z_]+\b|[A-Za-z][a-z]*/g;
	private static var words:Map<String, String>;
	
	public static function run(?args:Array<String>):Int {
		final args:Array<String> = args ?? Sys.args();
		
		if(args.contains("--help")) {
			Sys.print(usage);
			return 0;
		}
		
		final print:Bool = args.remove("--print-mirrored");
		
		final outputIndex:Int = args.indexOf("--output");
		var outputFile:String = null;
		if(outputIndex >= 0) {
			outputFile = args[outputIndex + 1];
			args.splice(outputIndex, 2);
		}
		
		if(args.length < 1) {
			Sys.stderr().writeString(usage);
			return 1;
		}
		
		final file1:String = args[0];
		if(!FileSystem.exists(file1)) {
			Sys.println("Could not find " + file1);
			return 1;
		}
		
		words = [
			"x" => "y",
			"horizontal" => "vertical",
			"horizontally" => "vertically",
			"width" => "height",
			"widths" => "heights",
			"row" => "column",
			"rows" => "columns",
			"left" => "top",
			"right" => "bottom",
			"center" => "middle"
		];
		
		for(xWord => yWord in words) {
			words[yWord] = xWord;
		}
		
		//Phase 1: generate a mirrored version of the first file.
		final originalLines1:Array<String> = File.getContent(file1).split("\n");
		final lines1:Array<String> = [];
		for(line in originalLines1) {
			lines1.push(wordMatcher.map(line, mirror));
		}
		
		if(args.length == 1) {
			if(outputFile != null) {
				File.saveContent(outputFile, lines1.join("\n"));
			} else {
				Sys.print(lines1.join("\n"));
			}
			return 0;
		}
		
		//Phase 2 (optional): compare with the second file.
		final file2:String = args[1];
		if(!FileSystem.exists(file2)) {
			Sys.println("Could not find " + file2);
			return 1;
		}
		
		final lines2:Array<String> = File.getContent(file2).split("\n");
		
		final mapping1:Array<Int> = [for(_ in 0...lines1.length) -1];
		final mapping2:Array<Int> = [for(_ in 0...lines2.length) -1];
		
		function matchLines(index1:Int, index2:Int, ?dryRun:Bool = false):Int {
			var count:Int = 0;
			
			index1--;
			index2--;
			while(++index1 < lines1.length && ++index2 < lines2.length) {
				var linesMatched:Int;
				
				if(mapping1[index1] >= 0 || mapping2[index2] >= 0) {
					break;
				} else if(lines1[index1] == lines2[index2]) {
					if(!dryRun) {
						mapping1[index1] = index2;
						mapping2[index2] = index1;
					}
					
					linesMatched = 1;
				} else if((linesMatched = merge(index1, index2, lines1, lines2, mapping1, mapping2, dryRun)) > 0) {
					index2 += linesMatched;
					index1 += linesMatched - 1;
				} else if((linesMatched = merge(index2, index1, lines2, lines1, mapping2, mapping1, dryRun)) > 0) {
					index1 += linesMatched;
					index2 += linesMatched - 1;
				} else {
					break;
				}
				
				count += linesMatched;
			}
			
			return count;
		}
		
		for(index1 in 0...lines1.length) {
			if(mapping1[index1] >= 0) {
				continue;
			}
			
			final line1:String = lines1[index1];
			
			var bestMatchCount:Int = 0;
			var bestMatchIndex2:Int = -1;
			
			var index2:Int = -1;
			while(true) {
				index2 = lines2.indexOf(line1, index2 + 1);
				if(index2 < 0) {
					break;
				}
				
				var matchCount:Int = matchLines(index1, index2, true);
				if(matchCount > bestMatchCount) {
					bestMatchCount = matchCount;
					bestMatchIndex2 = index2;
				}
			}
			
			if(bestMatchCount > 0 && bestMatchIndex2 >= 0) {
				matchLines(index1, bestMatchIndex2);
			}
		}
		
		//Gather information about the matched and unmatched lines.
		final unchangedLines1:Array<Int> = [];
		
		final sortedLines1:Array<String> = [];
		for(index2 => index1 in mapping2) {
			if(index1 >= 0) {
				sortedLines1.push(lines1[index1]);
			} else {
				final line2:String = lines2[index2];
				var matchIndex1:Int = -1;
				while(true) {
					matchIndex1 = originalLines1.indexOf(line2, matchIndex1 + 1);
					if(matchIndex1 < 0) {
						break;
					}
					
					if(mapping1[matchIndex1] < 0) {
						mapping1[matchIndex1] = index2;
						mapping2[index2] = matchIndex1;
						sortedLines1.push(lines1[matchIndex1]);
						
						if(!linesCouldBeEquivalent(lines1[matchIndex1], line2)) {
							unchangedLines1.push(matchIndex1);
						}
						
						break;
					}
				}
			}
		}
		
		//Print the results.
		if(unchangedLines1.length > 0) {
			Sys.stderr().writeString("The following lines aren't mirrored:\n\n");
			for(index1 in unchangedLines1) {
				Sys.stderr().writeString('$file1:${ index1 + 1 }: ${ originalLines1[index1] }\n');
				final index2:Int = mapping1[index1];
				if(index2 >= 0) {
					Sys.stderr().writeString('$file2:${ index2 + 1 }: ${ lines2[index2] }\n\n');
				} else {
					Sys.stderr().writeString('$file2:(unknown)\n\n');
				}
			}
		}
		
		if(mapping1.contains(-1) || mapping2.contains(-1)) {
			Sys.stderr().writeString("No matches were found for the following:\n\n");
			for(index1 => index2 in mapping1) {
				if(index2 == -1) {
					Sys.stderr().writeString('$file1:${ index1 + 1 }: ${ originalLines1[index1] }\n');
				}
			}
			for(index2 => index1 in mapping2) {
				if(index1 == -1) {
					Sys.stderr().writeString('$file2:${ index2 + 1 }: ${ lines2[index2] }\n');
				}
			}
		}
		
		if(outputFile != null) {
			File.saveContent(outputFile, sortedLines1.join("\n"));
		}
		
		return 0;
	}
	
	private static function mirror(wordMatcher:EReg):String {
		final word:String = wordMatcher.matched(0);
		if(cache.exists(word)) {
			return cache[word];
		}
		
		final lowercase:String = word.toLowerCase();
		if(words.exists(lowercase)) {
			var replacement:String = words[lowercase];
			if(word.charCodeAt(0) <= "Z".code) {
				if(word.length <= 1 || word.charCodeAt(1) <= "Z".code) {
					//The regex only allows more than one uppercase
					//letter if they're all uppercase.
					replacement = replacement.toUpperCase();
				} else {
					replacement = replacement.charAt(0).toUpperCase() + replacement.substring(1);
				}
			}
			
			cache[replacement] = word;
			return cache[word] = replacement;
		} else {
			return cache[word] = word;
		}
	}
	
	private static function merge(indexA:Int, indexB:Int, linesA:Array<String>, linesB:Array<String>, mappingA:Array<Int>, mappingB:Array<Int>, dryRun:Bool):Int {
		var count:Int = 0;
		
		var lineB:String = linesB[indexB];
		while(indexA < linesA.length && indexB < linesB.length) {
			final lineA:String = linesA[indexA];
			
			var mergedLinesB:String;
			if(lineA.startsWith(lineB) && indexB + 1 < linesB.length && lineStartMatcher.match(linesB[indexB + 1])
				&& (mergedLinesB = lineB + " " + lineStartMatcher.matchedRight()).startsWith(lineA)) {
				lineB = lineStartMatcher.matched(0) + mergedLinesB.substring(lineA.length + 1);
				final done:Bool = linesB[indexB + 1] == lineB;
				
				if(!dryRun) {
					linesB[indexB] = lineA;
					linesB[indexB + 1] = lineB;
					
					mappingA[indexA] = indexB;
					mappingB[indexB] = indexA;
					
					//Negative means it's not matched yet (so keep merging), but
					//if there ends up being nothing more to merge, don't report
					//it as an error.
					mappingB[indexB + 1] = -2;
				}
				
				indexA++;
				indexB++;
				count++;
				
				if(done) {
					break;
				}
			} else {
				break;
			}
		}
		
		return count;
	}
	
	private static function linesCouldBeEquivalent(line1:String, line2:String):Bool {
		if(line1.length != line2.length) {
			return false;
		}
		
		final chars1:Array<Int> = [for(i in 0...line1.length) line1.fastCodeAt(i)];
		chars1.sort(ascending);
		final chars2:Array<Int> = [for(i in 0...line2.length) line1.fastCodeAt(i)];
		chars2.sort(ascending);
		
		for(i in 0...chars1.length) {
			if(chars1[i] != chars2[i]) {
				return false;
			}
		}
		
		return true;
	}
	
	private static function ascending(a:Int, b:Int):Int {
		return a - b;
	}
}
