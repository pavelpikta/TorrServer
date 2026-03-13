import { Grid, OutlinedInput, Slider } from '@material-ui/core'
import { styled } from '@material-ui/core/styles'

const SliderInputWrapper = styled('div')`
  margin-bottom: 16px;
  min-width: 0;

  .slider-title {
    font-size: 14px;
    margin-bottom: 4px;
    word-break: break-word;

    @media (max-width: 600px) {
      font-size: 13px;
    }
  }
`

export default function SliderInput({
  isProMode,
  title,
  value,
  setValue,
  sliderMin,
  sliderMax,
  inputMin,
  inputMax,
  step = 1,
  onBlurCallback,
}) {
  const onBlur = ({ target: { value } }) => {
    if (value < inputMin) return setValue(inputMin)
    if (value > inputMax) return setValue(inputMax)

    onBlurCallback && onBlurCallback(value)
  }

  const onInputChange = ({ target: { value } }) => setValue(value === '' ? '' : Number(value))
  const onSliderChange = (_, newValue) => setValue(newValue)

  return (
    <SliderInputWrapper>
      <div className='slider-title'>{title}</div>

      <Grid container spacing={2} alignItems='center'>
        <Grid item xs style={{ minWidth: 0 }}>
          <Slider
            min={sliderMin}
            max={sliderMax}
            value={value}
            onChange={onSliderChange}
            step={step}
            color='secondary'
          />
        </Grid>

        {isProMode && (
          <Grid item style={{ flexShrink: 0 }}>
            <OutlinedInput
              value={value}
              margin='dense'
              onChange={onInputChange}
              onBlur={onBlur}
              style={{ width: '80px', minWidth: '80px', marginTop: '-6px' }}
              inputProps={{ step, min: inputMin, max: inputMax, type: 'number' }}
            />
          </Grid>
        )}
      </Grid>
    </SliderInputWrapper>
  )
}
