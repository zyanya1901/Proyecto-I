install.packages("tidyverse")
install.packages("janitor")

library(tidyverse)
library(janitor)

data <- read_csv("segregación_felicidad bajo_impacto_baja_probabilidad-table.csv", 
                 skip = 6) |>
  janitor::clean_names()

max_step <- max(data$step)

data |> 
  filter(step == max_step) |>
  ggplot(aes (x = indice_segregacion, y = mean_satisfaccion_of_turtles)) +
  geom_point (alpha = 0.5) +
  labs (x = "porcentaje de segregacion", y = "satisfaccion")
