module RedBook

	# General Settings
	config.debug =  true
	config.output = true
	config.colors = true
	config.completion = true
	config.duration_format = :minutes
	config.time_format = "%d/%m/%Y - %H:%M:%S"

	# Parser Settings
	config.parser.operation_prefix = ""
	config.parser.parameter_prefix = "-"
	config.parser.placeholder_prefix = ""

	config.op = config.parser.operation_prefix
	config.ph = config.parser.placeholder_prefix
	config.pm = config.parser.parameter_prefix

	# CLI Shortcuts
	config.cli.shortcuts = {}
	config.cli.shortcuts["\e\e"] = "#{config.op}quit"

	# Repositories
	config.repositories = {}
	config.repositories[:default] = RedBook::HOME_DIR/"repository.rbk"
	config.repositories[:personal] = RedBook::HOME_DIR/"personal.rbk"

	# Plugins
	config.plugins.list = [:tracking, :tagging, :aggregation, :detail]
	config.plugins.directories = [RedBook::LIB_DIR/'../plugins', RedBook::HOME_DIR/'.redbook-plugins', RedBook::HOME_DIR/'redbook-plugins']

	# Detail Plugin
	config.plugins.detail.details = [:code, :notes]
	config.plugins.detail.items = [:project, :version]

	# Tracking Plugin  
	config.plugins.tracking.macros = {}
	config.plugins.tracking.macros[:activity] = "#{config.op}log <#{config.ph}activity> #{config.pm}type activity"
	config.plugins.tracking.macros[:active] = "#{config.op}select #{config.pm}type activity #{config.pm}tracking started paused"
	config.plugins.tracking.macros[:activities] =  "#{config.op}select #{config.pm}type activity"
	config.plugins.tracking.macros[:foreground] = "#{config.op}update <#{config.ph}foreground> #{config.pm}foreground true"
	config.plugins.tracking.macros[:background] = "#{config.op}update <#{config.ph}background> #{config.pm}foreground false"

end
