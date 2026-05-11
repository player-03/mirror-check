package;

import mirror.Mirror;

class Run {
	public static function main():Void {
		final args:Array<String> = Sys.args();
		Sys.setCwd(args.pop());
		Sys.exit(Mirror.run(args));
	}
}

