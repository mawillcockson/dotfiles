export def dejavusansmono [] {
    # the reason I'm not `use`-ing `package install` commands here is that I
    # don't want to drag in `package` as a dependency
    run-external $nu.current-exe '-c' 'use package; package install dejavusansmono-nf'
}

export def main [] {
    dejavusansmono
}
