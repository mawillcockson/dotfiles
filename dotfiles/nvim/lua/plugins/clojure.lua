return {
  -- NOTE: I'd like to detect if scoop is installed and then install temurin-lts-jdk and clj-deps as required
  -- It used to be adoptopenjdk-lts-hotspot, which at one point was referenced in the exercism docs:
  -- https://github.com/exercism/clojure/blob/c1b58f4ed671a1f99d052201cde4fe19f62b36f6/docs/INSTALLATION.md
  -- This was changed at some point in the java bucket:
  -- https://github.com/ScoopInstaller/Java/issues/100#issuecomment-903529054
  -- As well, the clojure manifest was superceded by clj-deps:
  -- https://github.com/littleli/scoop-clojure/pull/194
  -- The scoop-clojure repository has a great wiki explaining the current setup steps:
  -- https://github.com/littleli/scoop-clojure/wiki/Getting-started
  "Olical/conjure",
  dependencies = {
    -- NOTE: :Clj not working
-- https://github.com/Olical/conjure/wiki/Quick-start:-Clojure#start-your-nrepl--cider-middleware
    "clojure-vim/vim-jack-in",
    "tpope/vim-dispatch",
    "radenling/vim-dispatch-neovim",
  },
}
