module RedBook

	# General Settings
	config.debug = false
	config.output = true
	config.colors = true
	config.completion = true
	
	# Repositories
	config.repositories.default = RedBook::HOME_DIR/"repository.rbk"

	# Plugins
	config.plugins.list = [:tracking, :tagging, :aggregation]
	config.plugins.directories = [RedBook::LIB_DIR/'../plugins', RedBook::HOME_DIR/'.redbook-plugins', RedBook::HOME_DIR/'redbook-plugins']

end
