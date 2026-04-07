install.packages("tidyverse")
install.packages("janitor")

library(tidyverse)
library(janitor)

archivo1 <- read_csv("polarizacion_extension_redes psi_latice_cuadrada-table.csv", 
                 skip = 6) |>
  janitor::clean_names()

archivo2 <- read_csv("polarizacion_extension_redes psi_red_aleatoria-table.csv",
                  skip = 6) |>
  janitor::clean_names()

archivo3 <- read_csv("polarizacion_extension_redes psi_libre_de_escala-table.csv",
                     skip = 6) |>
  janitor::clean_names()

data <- bind_rows(archivo1, archivo2, archivo3)

max_step <- max(data$step)

data |> 
    filter(step == max_step) |> 
    ggplot(aes(x = gamma, y = psi)) + 
    geom_point(alpha = 0.5) +
    facet_grid( . ~ tipo_red) + 
  labs (x = expression(gamma), y = expression(Psi)) +
  scale_x_continuous(breaks = seq (0,1, by = 0.2))

  





