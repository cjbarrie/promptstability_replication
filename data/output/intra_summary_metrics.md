# Intra-PSS Summary Metrics

Generated from rescored within-prompt outputs.

## Cumulative

| dataset | final alpha | final CI width | run count to estimate stability | run count to precision stability | max abs deviation from final |
| --- | ---: | ---: | ---: | ---: | ---: |
| manifestos | 0.923 | 0.011 | 5 | 11 | 0.011 |
| manifestos_multi | 0.975 | 0.005 | 3 | 4 | 0.012 |
| mii | 0.935 | 0.008 | 3 | 7 | 0.011 |
| mii_long | 0.919 | 0.008 | 2 | 7 | 0.009 |
| news | 0.951 | 0.007 | 2 | 6 | 0.010 |
| news_short | 0.923 | 0.020 | 14 | 29 | 0.039 |
| stance | 0.931 | 0.009 | 4 | 9 | 0.014 |
| stance_long | 0.956 | 0.009 | 6 | 9 | 0.012 |
| synth | 0.946 | 0.008 | 2 | 7 | 0.010 |
| synth_short | 0.820 | 0.019 | 7 | 28 | 0.047 |
| tweets_pop | 0.947 | 0.019 | 12 | 28 | 0.053 |
| tweets_rd | 0.952 | 0.017 | 3 | 21 | 0.013 |

## Adjacent

| dataset | mean alpha | sd alpha | IQR alpha | min alpha | max alpha | share below threshold | mean CI width |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| manifestos | 0.924 | 0.017 | 0.018 | 0.884 | 0.959 | 0.000 | 0.101 |
| manifestos_multi | 0.975 | 0.009 | 0.015 | 0.956 | 0.987 | 0.000 | 0.029 |
| mii | 0.941 | 0.008 | 0.011 | 0.927 | 0.952 | 0.000 | 0.061 |
| mii_long | 0.921 | 0.014 | 0.024 | 0.883 | 0.942 | 0.000 | 0.063 |
| news | 0.954 | 0.013 | 0.022 | 0.934 | 0.973 | 0.000 | 0.061 |
| news_short | 0.932 | 0.038 | 0.057 | 0.845 | 0.981 | 0.000 | 0.149 |
| stance | 0.931 | 0.013 | 0.015 | 0.903 | 0.952 | 0.000 | 0.085 |
| stance_long | 0.958 | 0.012 | 0.020 | 0.932 | 0.981 | 0.000 | 0.075 |
| synth | 0.946 | 0.014 | 0.019 | 0.924 | 0.972 | 0.000 | 0.068 |
| synth_short | 0.822 | 0.025 | 0.032 | 0.771 | 0.866 | 0.172 | 0.171 |
| tweets_pop | 0.950 | 0.023 | 0.023 | 0.914 | 1 | 0.000 | 0.125 |
| tweets_rd | 0.951 | 0.027 | 0.041 | 0.900 | 1 | 0.000 | 0.120 |
