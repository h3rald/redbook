module RedBook

	# General Settings
	config.debug =  true
	config.output = true
	config.colors = true
	config.completion = true
	config.duration_format = :minutes
	config.time_format = "%d/%m/%Y - %H:%M:%S"

	# CLI Shortcuts
	config.cli.shortcuts = {}
	config.cli.shortcuts["\e\e"] = "quit"

	# Repositories
	config.repositories = {}
	config.repositories[:default] = RedBook::HOME_DIR/"repository.rbk"
	config.repositories[:personal] = RedBook::HOME_DIR/"personal.rbk"

	# Plugins
	config.plugins.list = [:tracking, :tagging, :aggregation, :detail]
	config.plugins.directories = [RedBook::LIB_DIR/'../plugins', RedBook::HOME_DIR/'.redbook-plugins', RedBook::HOME_DIR/'redbook-plugins']

	# Detail Plugin
	config.details = [:code, :notes]
	config.items = [:project, :version]

	# Macros
	config.macros.tracking = {}
	config.macros.tracking[:activity] = "log <activity> -type activity"
	config.macros.tracking[:active] = "select -type activity -tracking started paused"
	config.macros.tracking[:activities] =  "select -type activity"
	config.macros.tracking[:foreground] = "update <foreground> -foreground true"
	config.macros.tracking[:background] = "update <background> -foreground false"

end
