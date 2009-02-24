module RedBook

	# General Settings
	config.debug =  true
	config.output = true
	config.colors = true
	config.completion = true
	config.duration_format = :minutes
	config.time_format = "%d/%m/%Y - %H:%M:%S"

	# Repositories
	config.repositories = {}
	config.repositories[:default] = RedBook::HOME_DIR/"repository.rbk"
	config.repositories[:personal] = RedBook::HOME_DIR/"personal.rbk"

	# Plugins
	config.plugins.list = [:tracking, :tagging, :aggregation]
	config.plugins.directories = [RedBook::LIB_DIR/'../plugins', RedBook::HOME_DIR/'.redbook-plugins', RedBook::HOME_DIR/'redbook-plugins']

	# Tracking Plugin
	config.plugins.tracking.macros = {}
	config.plugins.tracking.macros[:activity] = ":log <:activity> :type activity"
	config.plugins.tracking.macros[:activities] =  ":select :type activity"
	config.plugins.tracking.macros[:foreground] = ":update <:foreground> :foreground true"
	config.plugins.tracking.macros[:background] = ":update <:background> :foreground false"

end
