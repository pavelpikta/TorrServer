// import ListItem from '@mui/material/ListItem'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
// import List from '@mui/material/List'
import ButtonGroup from '@mui/material/ButtonGroup'
import Button from '@mui/material/Button'
import { useTranslation } from 'react-i18next'
import { StyledDialog } from 'style/CustomMaterialUiStyles'
import useOnStandaloneAppOutsideClick from 'utils/useOnStandaloneAppOutsideClick'

// const donateFrame = '<iframe src="https://yoomoney.ru/quickpay/shop-widget?writer=seller&targets=TorrServer Donate&targets-hint=&default-sum=200&button-text=14&payment-type-choice=on&mobile-payment-type-choice=on&comment=on&hint=&successURL=&quickpay=shop&account=410013733697114" width="320" height="320" frameborder="0" allowtransparency="true" scrolling="no"></iframe>'

export default function DonateDialog({ onClose }) {
  const { t } = useTranslation()
  const ref = useOnStandaloneAppOutsideClick(onClose)

  return (
    <StyledDialog open onClose={onClose} aria-labelledby='form-dialog-title' fullWidth maxWidth='xs' ref={ref}>
      <DialogTitle id='form-dialog-title'>{t('Donate')}</DialogTitle>
      <DialogContent>
        {/* <List> */}
        {/* <ListItem key='DonateLinks'> */}
        <ButtonGroup variant='outlined' color='secondary' aria-label='contained primary button group'>
          <Button onClick={() => window.open('https://boosty.to/yourok', '_blank')}>Boosty</Button>
          <Button onClick={() => window.open('https://yoomoney.ru/to/410013733697114', '_blank')}>IO.Money</Button>
          <Button onClick={() => window.open('https://www.tbank.ru/cf/742qEMhKhKn', '_blank')}>TBank</Button>
          {/* <Button onClick={() => window.open('https://qiwi.com/n/YOUROK85', '_blank')}>QIWI</Button> */}
          {/* <Button onClick={() => window.open('https://www.paypal.com/paypalme/yourok', '_blank')}>PayPal</Button> */}
        </ButtonGroup>
        {/* </ListItem> */}
        {/* <ListItem key='DonateForm'> */}
        {/* eslint-disable-next-line react/no-danger */}
        {/* <div dangerouslySetInnerHTML={{ __html: donateFrame }} /> */}
        {/* </ListItem> */}
        {/* </List> */}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} color='secondary' variant='contained'>
          Ok
        </Button>
      </DialogActions>
    </StyledDialog>
  )
}
