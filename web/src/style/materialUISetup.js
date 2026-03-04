import { createTheme } from '@mui/material/styles'
import { useMediaQuery } from '@mui/material'
import { useEffect, useMemo, useState } from 'react'

import { mainColors, themeColors } from './colors'

export const THEME_MODES = { LIGHT: 'light', DARK: 'dark', AUTO: 'auto' }

const typography = { fontFamily: 'Open Sans, sans-serif' }

export const darkTheme = createTheme({
  typography,
  palette: {
    mode: THEME_MODES.DARK,
    primary: { main: mainColors.dark.primary },
    secondary: { main: mainColors.dark.secondary },
  },
})
export const lightTheme = createTheme({
  typography,
  palette: {
    mode: THEME_MODES.LIGHT,
    primary: { main: mainColors.light.primary },
    secondary: { main: mainColors.light.secondary },
  },
})

export const useMaterialUITheme = () => {
  const savedThemeMode = localStorage.getItem('themeMode')
  const isSystemModeDark = useMediaQuery('(prefers-color-scheme: dark)')
  const [isDarkMode, setIsDarkMode] = useState(savedThemeMode === 'dark' || isSystemModeDark)
  const [currentThemeMode, setCurrentThemeMode] = useState(savedThemeMode || THEME_MODES.AUTO)

  const updateThemeMode = mode => {
    setCurrentThemeMode(mode)
    localStorage.setItem('themeMode', mode)
  }

  useEffect(() => {
    currentThemeMode === THEME_MODES.LIGHT && setIsDarkMode(false)
    currentThemeMode === THEME_MODES.DARK && setIsDarkMode(true)
    currentThemeMode === THEME_MODES.AUTO && setIsDarkMode(isSystemModeDark)
  }, [isSystemModeDark, currentThemeMode])

  const theme = isDarkMode ? THEME_MODES.DARK : THEME_MODES.LIGHT

  const muiTheme = useMemo(
    () =>
      createTheme({
        typography,
        palette: {
          mode: theme,
          primary: { main: mainColors[theme].primary },
          secondary: { main: mainColors[theme].secondary },
        },
        components: {
          MuiTypography: {
            styleOverrides: {
              h6: {
                fontSize: '1.0rem',
              },
            },
          },
          MuiPaper: {
            styleOverrides: {
              root: {
                backgroundColor: themeColors[theme].app.paperColor,
              },
            },
          },
          MuiInputBase: {
            styleOverrides: {
              input: {
                color: mainColors[theme].labels,
              },
            },
          },
          MuiFormControlLabel: {
            styleOverrides: {
              labelPlacementStart: {
                display: 'flex',
                justifyContent: 'space-between',
                marginStart: 0,
                marginTop: 6,
                marginBottom: 2,
              },
            },
          },
          MuiInputLabel: {
            styleOverrides: {
              root: {
                color: mainColors[theme].labels,
                marginBottom: 8,
                '&.Mui-focused': {
                  color: mainColors[theme].labels,
                },
              },
            },
          },
          MuiFormGroup: {
            styleOverrides: {
              root: {
                '& .MuiFormHelperText-root': {
                  marginTop: -8,
                },
              },
            },
          },
        },
      }),
    [theme],
  )

  return [isDarkMode, currentThemeMode, updateThemeMode, muiTheme]
}
