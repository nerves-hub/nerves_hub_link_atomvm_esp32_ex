# The level tests log at every level on purpose, and printing all of it buries
# the test output. Nothing here asserts on what a handler received.
:logger.set_primary_config(:level, :none)

ExUnit.start()
