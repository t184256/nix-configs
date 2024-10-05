@events.on_ptk_create
def ptk_init(bindings, **kw):
    #from prompt_toolkit.application.current import get_app
    #app = get_app()
    #app.ttimeoutlen = 0.005
    #app.timeoutlen = None

    from prompt_toolkit.keys import Keys
    @bindings.add(Keys.Insert)
    def ignore_insert(event):
        pass  # I use it for language indication with ambiguous symbols
