import sys

try:
    import invoke
finally:
    print("Cannot import invoke.\nPlease run install.py first, or report this error", file=sys.stderr)
    sys.exit(1)



#python -m pip install --user pipx
#python -m pipx ensurepath
#source ~/.profile
#pipx install dotdrop
#mkdir ~/projects
#git clone git@github.com:mawillcockson/dotfiles.git projects/dotfiles
#alias dotdrop='dotdrop --cfg=~/projects/dotfiles/config.yaml'
#dotdrop install
