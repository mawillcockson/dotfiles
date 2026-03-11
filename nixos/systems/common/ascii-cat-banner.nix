{
  catIndex ? 5,
  bannerLines,
  moveShortestDownBy ? 0,
  leftBorder ? ">>",
  rightBorder ? "<<",
  borderPaddingAmount ? 3,
  interBannerArtPadding ? 1,
  lib,
  ...
}: let
  ascii_cats = [
    ''
      ---
         |\---/|
         | ,_, |
          \_`_/-..----.
       ___/ `   ' ,""+ \  sk
      (__...'   __\    |`.___.';
        (_,...'(_,.`__)/'.....+
        Art credit: SK - thank you!
      ---
    ''
    ''
      ---
           \    /\
            )  ( ')
           (  /  )
      jgs   \(__)|
      ---
    ''
    ''
      ---
      ((      /|_/|
       \\.._.'  , ,\
       /\ | '.__ v /
      (_ .   /   "
       ) _)._  _ /
      '.\ \|( / ( mrf
        ''' '''\\ \\
      ---
    ''
    ''
      ---
         ("`-/")_.-'"``-._
          . . `; -._    )-;-,_`)
         (v_,)'  _  )`-.\  ``-'
        _.- _..-_/ / ((.'
      ((,.-'   ((,/    Felix Lee
      ---
    ''
    ''
      ---
               __..--'''``\--....___   _..,_
           _.-'    .-/";  `        ``<._  ``-+'~=.
       _.-' _..--.'_    \                    `(^) )
      ((..-'    (< _     ;_..__               ; `'   fL
                 `-._,_)'      ``--...____..-'
      ---
    ''
    ''
      ---
      _                ___       _.--.
      \`.|\..----...-'`   `-._.-' .-'`
      /  ' `         ,       __.-'
      )/' _/     \   `-_,   /
      `-'" `"\_  ,_.-;_.-\_ ',     fsc/as
          _.-'_./   {_.'   ; /
         {_.-``-'         {_/
      ---
    ''
    ''
      ---
                         .-.
                          \ \
                           \ \
                           | |
                           | |
         /\---/\   _,---._ | |
        /^   ^  \,'       `. ;
       ( O   O   )           ;
        `.=o=__,'            \
          /         _,--.__   \
         /  _ )   ,'   `-. `-. \
        / ,' /  ,'        \ \ \ \
       / /  / ,'          (,_)(,_)
      (,;  (,,)      jrei
      Art credit: jrei - thank you!
      ---
    ''
  ];
  cat = builtins.elemAt ascii_cats catIndex |> lib.strings.trim;
  catLines = cat |> lib.strings.splitString "\n";
  catLinesNoGuards = catLines |> builtins.tail |> lib.lists.init;
  stringLength = s: s |> lib.strings.stringToCharacters |> builtins.length;
  maxInt = left: right:
    if left > right
    then left
    else right;
  longestLength = l: map stringLength l |> builtins.foldl' maxInt 0;
  longestBannerLength = longestLength bannerLines;
  mkPadding = amount: lib.strings.replicate amount " ";
  horizontallyCenteredBannerLines =
    bannerLines
    |> map (
      l: let
        length = stringLength l;
        leftPadding =
          (longestBannerLength - length)
          / 2.0
          |> builtins.ceil
          |> builtins.add borderPaddingAmount
          |> mkPadding;
        rightPadding =
          (longestBannerLength - length)
          / 2.0
          |> builtins.floor
          |> builtins.add interBannerArtPadding
          |> mkPadding;
      in
        leftBorder + leftPadding + l + rightPadding
    );
  tallest = let
    artHeight = builtins.length catLinesNoGuards;
    bannerHeight = builtins.length bannerLines;
  in
    maxInt artHeight bannerHeight;
  centerVertically = (
    l: let
      height = builtins.length l;
    in
      if height >= tallest
      then l
      else let
        fillerLine =
          leftBorder
          + (lib.strings.replicate (longestBannerLength + borderPaddingAmount + interBannerArtPadding) " ");
        missing = tallest - height;
        aboveAmount = missing / 2.0 |> builtins.ceil |> builtins.add moveShortestDownBy |> maxInt 0;
        belowAmount = missing - aboveAmount |> maxInt 0;
        above = lib.lists.replicate aboveAmount fillerLine;
        below = lib.lists.replicate belowAmount fillerLine;
      in
        builtins.concatLists [
          above
          l
          below
        ]
  );
  centeredBannerLines = centerVertically horizontallyCenteredBannerLines;
  longestCatLength = longestLength catLinesNoGuards;
  appendedCatLines =
    catLinesNoGuards
    |> map (
      line: let
        rightPadding = lib.strings.replicate (
          longestCatLength - (stringLength line) + borderPaddingAmount
        ) " ";
      in
        line + rightPadding + rightBorder
    );
  centeredCatLines = centerVertically appendedCatLines;
in
  lib.lists.zipListsWith (a: b: a + b) centeredBannerLines centeredCatLines
  |> lib.strings.concatStringsSep "\n"
