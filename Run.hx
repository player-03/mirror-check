package;

import mirror.MirrorCheck;

using StringTools;

class Run {
	private static function main():Void {
		final args:Array<String> = Sys.args();
		Sys.setCwd(args.pop());
		
		if(args.length != 2) {
			Sys.println("Usage: haxelib run mirror-check path/to/File1.hx path/to/File2.hx");
			return;
		}
		
		MirrorCheck.checkFiles(args[0], args[1]);
	}
}

