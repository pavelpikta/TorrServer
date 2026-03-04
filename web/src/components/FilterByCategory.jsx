import ListItem from '@mui/material/ListItem'
import ListItemIcon from '@mui/material/ListItemIcon'
import ListItemText from '@mui/material/ListItemText'
import { useTranslation } from 'react-i18next'

export default function FilterByCategory({ categoryKey, categoryName, setGlobalFilterCategory, icon }) {
  const onClick = () => {
    setGlobalFilterCategory(categoryKey)
  }
  const { t } = useTranslation()

  return (
    <>
      <ListItem button key={categoryKey} onClick={onClick}>
        <ListItemIcon>{icon}</ListItemIcon>
        <ListItemText primary={t(categoryName)} />
      </ListItem>
    </>
  )
}
