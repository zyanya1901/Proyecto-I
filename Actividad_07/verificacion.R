install.packages("tidyverse")
install.packages("janitor")

library(tidyverse)
library(janitor)

data <- read_csv("modelo_trafico verificacion_homogenea-table.csv", 
                 skip = 6) |> 
  janitor::clean_names()

max_step <- max(data$step)

data |> 
  filter(step == max_step) |>
  ggplot(aes(x = numero_de_carros_5 / world_width, y = flujo_promedio)) +
  geom_point(alpha = 0.5) +
  labs( x = expression(p), y = expression(q))

 
 