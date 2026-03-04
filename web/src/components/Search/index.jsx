import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import ListItemIcon from '@mui/material/ListItemIcon'
import SearchIcon from '@mui/icons-material/Search'
import ListItemText from '@mui/material/ListItemText'
import ListItemButton from '@mui/material/ListItemButton'

import SearchDialog from './SearchDialog'

export default function SearchDialogButton({ isOffline, isLoading }) {
  const { t } = useTranslation()
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const handleClickOpen = () => setIsDialogOpen(true)
  const handleClose = () => setIsDialogOpen(false)

  return (
    <>
      <ListItemButton onClick={handleClickOpen} disabled={isOffline || isLoading}>
        <ListItemIcon>
          <SearchIcon />
        </ListItemIcon>
        <ListItemText primary={t('Search')} />
      </ListItemButton>

      {isDialogOpen && <SearchDialog handleClose={handleClose} />}
    </>
  )
}
