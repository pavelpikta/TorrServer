import { useState } from 'react'
import Button from '@mui/material/Button'
import Snackbar from '@mui/material/Snackbar'
import IconButton from '@mui/material/IconButton'
import CreditCardIcon from '@mui/icons-material/CreditCard'
import CloseIcon from '@mui/icons-material/Close'
import { useTranslation } from 'react-i18next'
import styled from 'styled-components'
import { standaloneMedia } from 'style/standaloneMedia'

import DonateDialog from './DonateDialog'

const StyledSnackbar = styled(Snackbar)`
  ${standaloneMedia('margin-bottom: 90px')};
`

export default function DonateSnackbar() {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [snackbarOpen, setSnackbarOpen] = useState(true)

  const disableSnackbar = () => {
    setSnackbarOpen(false)
    localStorage.setItem('snackbarIsClosed', true)
  }

  return (
    <>
      {open && <DonateDialog onClose={() => setOpen(false)} />}

      <StyledSnackbar
        anchorOrigin={{
          vertical: 'bottom',
          horizontal: 'center',
        }}
        open={snackbarOpen}
        onClose={disableSnackbar}
        message={t('Donate?')}
        action={
          <>
            <Button
              style={{ marginRight: '10px' }}
              color='secondary'
              size='small'
              onClick={() => {
                setOpen(true)
                disableSnackbar()
              }}
            >
              <CreditCardIcon style={{ marginRight: '10px' }} fontSize='small' />
              {t('Support')}
            </Button>

            <IconButton size='small' aria-label='close' color='inherit' onClick={disableSnackbar}>
              <CloseIcon fontSize='small' />
            </IconButton>
          </>
        }
      />
    </>
  )
}
