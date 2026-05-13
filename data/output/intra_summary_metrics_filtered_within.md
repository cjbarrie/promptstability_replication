# Filtered Intra-PSS Summary Metrics

Generated from rescored filtered within-prompt outputs.

## Filtered

### Cumulative

| dataset | final alpha | final CI width | run count to estimate stability | run count to precision stability | max abs deviation from final |
| --- | ---: | ---: | ---: | ---: | ---: |
| manifestos | 0.923 | 0.012 | 5 | 12 | 0.013 |
| manifestos_multi | 0.975 | 0.006 | 3 | 5 | 0.012 |
| mii | 1.000 | 0.000 | 2 | 2 | 0.000 |
| mii_long | 0.999 | 0.001 | 2 | 2 | 0.003 |
| news | 0.951 | 0.007 | 4 | 6 | 0.010 |
| news_short | 0.923 | 0.020 | 13 |  | 0.039 |
| stance | 0.932 | 0.009 | 4 | 9 | 0.015 |
| stance_long | 0.956 | 0.009 | 6 | 9 | 0.011 |
| synth | 0.946 | 0.008 | 2 | 7 | 0.010 |
| synth_short | 0.821 | 0.019 | 7 | 30 | 0.044 |
| tweets_pop | 0.947 | 0.019 | 11 | 27 | 0.053 |
| tweets_rd | 0.953 | 0.017 | 3 | 21 | 0.013 |

### Adjacent

| dataset | mean alpha | sd alpha | IQR alpha | min alpha | max alpha | share below threshold | mean CI width |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| manifestos | 0.924 | 0.017 | 0.017 | 0.883 | 0.957 | 0.000 | 0.101 |
| manifestos_multi | 0.975 | 0.009 | 0.015 | 0.956 | 0.987 | 0.000 | 0.029 |
| mii | 1.000 | 0.001 | 0.000 | 0.996 | 1 | 0.000 | 0.001 |
| mii_long | 1.000 | 0.001 | 0.000 | 0.996 | 1 | 0.000 | 0.001 |
| news | 0.954 | 0.013 | 0.022 | 0.934 | 0.974 | 0.000 | 0.062 |
| news_short | 0.932 | 0.037 | 0.053 | 0.846 | 0.982 | 0.000 | 0.149 |
| stance | 0.932 | 0.013 | 0.012 | 0.908 | 0.953 | 0.000 | 0.085 |
| stance_long | 0.958 | 0.012 | 0.019 | 0.931 | 0.981 | 0.000 | 0.074 |
| synth | 0.946 | 0.014 | 0.020 | 0.924 | 0.972 | 0.000 | 0.068 |
| synth_short | 0.822 | 0.025 | 0.029 | 0.769 | 0.865 | 0.172 | 0.171 |
| tweets_pop | 0.951 | 0.022 | 0.021 | 0.914 | 1 | 0.000 | 0.125 |
| tweets_rd | 0.951 | 0.027 | 0.041 | 0.897 | 1 | 0.000 | 0.120 |

## Filtered & Balanced

### Cumulative

| dataset | final alpha | final CI width | run count to estimate stability | run count to precision stability | max abs deviation from final |
| --- | ---: | ---: | ---: | ---: | ---: |
| manifestos | 0.923 | 0.011 | 5 | 11 | 0.012 |
| manifestos_multi | 0.975 | 0.006 | 3 | 4 | 0.011 |
| mii | 1.000 | 0.000 | 2 | 2 | 0.000 |
| mii_long | 0.999 | 0.001 | 2 | 2 | 0.003 |
| news | 0.951 | 0.007 | 4 | 6 | 0.011 |
| news_short | 0.923 | 0.021 | 13 |  | 0.040 |
| stance | 0.931 | 0.009 | 4 | 9 | 0.016 |
| stance_long | 0.956 | 0.009 | 6 | 9 | 0.011 |
| synth | 0.947 | 0.008 | 3 | 7 | 0.011 |
| synth_short | 0.821 | 0.019 | 7 | 29 | 0.045 |
| tweets_pop | 0.947 | 0.019 | 12 | 27 | 0.053 |
| tweets_rd | 0.953 | 0.017 | 3 | 21 | 0.014 |

### Adjacent

| dataset | mean alpha | sd alpha | IQR alpha | min alpha | max alpha | share below threshold | mean CI width |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| manifestos | 0.924 | 0.018 | 0.019 | 0.882 | 0.958 | 0.000 | 0.101 |
| manifestos_multi | 0.975 | 0.009 | 0.014 | 0.957 | 0.987 | 0.000 | 0.030 |
| mii | 1.000 | 0.001 | 0.000 | 0.996 | 1 | 0.000 | 0.001 |
| mii_long | 1.000 | 0.001 | 0.000 | 0.995 | 1 | 0.000 | 0.001 |
| news | 0.954 | 0.013 | 0.024 | 0.934 | 0.973 | 0.000 | 0.061 |
| news_short | 0.932 | 0.037 | 0.055 | 0.849 | 0.982 | 0.000 | 0.149 |
| stance | 0.932 | 0.013 | 0.010 | 0.908 | 0.952 | 0.000 | 0.086 |
| stance_long | 0.958 | 0.012 | 0.019 | 0.930 | 0.982 | 0.000 | 0.074 |
| synth | 0.946 | 0.014 | 0.019 | 0.923 | 0.972 | 0.000 | 0.069 |
| synth_short | 0.823 | 0.026 | 0.030 | 0.765 | 0.866 | 0.138 | 0.171 |
| tweets_pop | 0.951 | 0.022 | 0.022 | 0.916 | 1 | 0.000 | 0.125 |
| tweets_rd | 0.951 | 0.027 | 0.041 | 0.898 | 1 | 0.000 | 0.119 |

