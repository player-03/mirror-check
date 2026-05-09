package mirror;

import sys.io.File;
import sys.FileSystem;

using StringTools;

class MirrorCheck {
	private static final cache:Map<String, String> = new Map();
	private static final spaceMatcher:EReg = ~/^\s*(?:\/\/ ?)?/;
	private static final wordMatcher:EReg = ~/\b[A-Z_]+\b|[A-Za-z][a-z]*/g;
	private static var words:Map<String, String>;
	
	public static function checkFiles(fileA:String, fileB:String):Void {
		if(!FileSystem.exists(fileA)) {
			Sys.println("Could not find " + fileA);
			return;
		}
		if(!FileSystem.exists(fileB)) {
			Sys.println("Could not find " + fileB);
			return;
		}
		
		if(words == null) {
			words = [
				"x" => "y",
				"horizontal" => "vertical",
				"horizontally" => "vertically",
				"width" => "height",
				"row" => "column",
				"rows" => "columns",
				"left" => "top",
				"right" => "bottom",
				"center" => "middle"
			];

			for (xWord => yWord in words) {
				words[yWord] = xWord;
			}
		}
		
		final linesA:Array<String> = File.getContent(fileA).split("\n");
		final linesB:Array<String> = File.getContent(fileB).split("\n");
		final lineNumbersA:Array<Int> = [for(i in 1...(linesA.length + 1)) i];
		final lineNumbersB:Array<Int> = [for(i in 1...(linesB.length + 1)) i];
		
		var mismatchFound:Bool = false;
		var indexA:Int = -1;
		var indexB:Int = -1;
		while(++indexA < linesA.length && ++indexB < linesB.length) {
			final lineA:String = linesA[indexA];
			final lineB:String = linesB[indexB];
			
			final lineAMirrored:String = getMirrored(lineA);
			if(lineAMirrored == lineB) {
				continue;
			}
			
			//Special case: if one line is just a bit longer than the other,
			//assume it's a word wrapping issue and move the remainder to the
			//next line.
			final lineBMirrored:String = getMirrored(lineB);
			if(lineA.startsWith(lineBMirrored) && lineA.charCodeAt(lineBMirrored.length) == " ".code) {
				spaceMatcher.match(linesA[indexA + 1]);
				if(spaceMatcher.matchedRight().length > 0) {
					linesA[indexA + 1] = spaceMatcher.matched(0) + lineA.substring(lineBMirrored.length + 1) + " " + spaceMatcher.matchedRight();
					linesA[indexA] = lineBMirrored;
				} else {
					//Skip checking the wrapped text and fix the line count
					//mismatch. This is slightly incorrect, but it's not a lot
					//of text being skipped.
					indexB++;
				}
				continue;
			} else if(lineB.startsWith(lineAMirrored) && lineB.charCodeAt(lineAMirrored.length) == " ".code) {
				spaceMatcher.match(linesB[indexB + 1]);
				if(spaceMatcher.matchedRight().length > 0) {
					linesB[indexB + 1] = spaceMatcher.matched(0) + lineB.substring(lineAMirrored.length + 1) + " " + spaceMatcher.matchedRight();
					linesB[indexB] = lineAMirrored;
				} else {
					//Skip checking the wrapped text and fix the line count
					//mismatch. This is slightly incorrect, but it's not a lot
					//of text being skipped.
					indexA++;
				}
				continue;
			}
			
			//Special case: be lenient about the exact order.
			final mirroredIndexA:Int = linesA.indexOf(lineBMirrored, indexA);
			if(mirroredIndexA > indexA && mirroredIndexA - indexA < 6) {
				final temp:String = linesA[indexA];
				linesA[indexA] = linesA[mirroredIndexA];
				linesA[mirroredIndexA] = temp;
				
				final temp:Int = lineNumbersA[indexA];
				lineNumbersA[indexA] = lineNumbersA[mirroredIndexA];
				lineNumbersA[mirroredIndexA] = temp;
				
				continue;
			}
			
			Sys.println("Mismatch:\n"
				+ '  $fileA:${ lineNumbersA[indexA] }: $lineA\n'
				+ '  $fileB:${ lineNumbersB[indexB] }: $lineB\n'
			);
			mismatchFound = true;
		}
		
		if(!mismatchFound) {
			Sys.println('$fileA matches $fileB.');
		}
	}
	
	public static function getMirrored(phrase:String):String {
		if(cache.exists(phrase)) {
			return cache[phrase];
		} else {
			final mirrorPhrase:String = wordMatcher.map(phrase, wordMatcher -> {
				final match:String = wordMatcher.matched(0);
				final lowercase:String = match.toLowerCase();
				if(words.exists(lowercase)) {
					var replacement:String = words[lowercase];
					if(match.charCodeAt(0) <= "Z".code) {
						if(match.length <= 1 || match.charCodeAt(1) <= "Z".code) {
							//The regex only allows more than one uppercase
							//letter if they're all uppercase.
							replacement = replacement.toUpperCase();
						} else {
							replacement = replacement.charAt(0).toUpperCase() + replacement.substring(1);
						}
					}
					return replacement;
				} else {
					return match;
				}
			});
			
			cache[phrase] = mirrorPhrase;
			cache[mirrorPhrase] = phrase;
			return mirrorPhrase;
		}
	}
}

