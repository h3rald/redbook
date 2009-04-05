module RedBook

	# General Settings
	config.debug =  true
	config.output = true
	config.colors = true
	config.completion = true
	config.duration_format = :minutes
	config.time_format = "%d/%m/%Y - %H:%M:%S"
	config.templates.directories = [LIB_DIR/'../templates']

	# CLI Shortcuts
	config.cli.shortcuts = {}
	config.cli.shortcuts["\e\e"] = "quit"

	# Repositories
	config.repositories = {}
	config.repositories[:default] = RedBook::HOME_DIR/"repository.rbk"
	config.repositories[:personal] = RedBook::HOME_DIR/"personal.rbk"

	# Plugins
	config.plugins.list = [:tracking, :tagging, :aggregation, :detail, :archiving]
	config.plugins.directories = [LIB_DIR/'../plugins', HOME_DIR/'.redbook-plugins', HOME_DIR/'redbook-plugins']

	# Detail Plugin
	config.details = [:code, :notes]
	config.items = [:project, :version]

	# Archiving Plugin
	config.archiving.directory = RedBook::HOME_DIR/'backup'

	# Aggregation Plugin
	config.calculation_fields = {}
	config.calculation_fields[:duration] = 'activity.duration'

	# Macros
	config.macros.tracking = {}
	config.macros.tracking[:activity] = "log <activity> -type activity"
	config.macros.tracking[:active] = "select -type activity -tracking started paused"
	config.macros.tracking[:activities] =  "select -type activity"
	config.macros.tracking[:foreground] = "update <foreground> -foreground true"
	config.macros.tracking[:background] = "update <background> -foreground false"

end
