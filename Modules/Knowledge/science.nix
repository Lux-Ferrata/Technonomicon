{ ... }: {
  flake.nixosModules.Tn-science = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      # Numerical computing
      julia-bin
      octave
      gnuplot
      (rWrapper.override {
        packages = with rPackages; [
          tidyverse
          ggplot2
          rmarkdown
          knitr
          reticulate
          IRkernel
        ];
      })
      # Symbolic / computer algebra
      maxima
      gap
      sage
      # Proof assistant
      lean4
      # Reproducible documents (integrates R, Python, Julia)
      quarto
      # Modern document preparation
      typst
    ];
  };
}
