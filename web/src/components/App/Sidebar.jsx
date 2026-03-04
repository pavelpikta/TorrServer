import Divider from '@mui/material/Divider'
import ListItem from '@mui/material/ListItem'
import ListItemIcon from '@mui/material/ListItemIcon'
import ListItemText from '@mui/material/ListItemText'
import { CreditCard as CreditCardIcon } from '@mui/icons-material'
import List from '@mui/material/List'
import { useTranslation } from 'react-i18next'
import AddDialogButton from 'components/Add'
import SettingsDialog from 'components/Settings'
import RemoveAll from 'components/RemoveAll'
import AboutDialog from 'components/About'
import CloseServer from 'components/CloseServer'
import SearchDialogButton from 'components/Search'
import { memo } from 'react'
import CheckIcon from '@mui/icons-material/Check'
import ClearIcon from '@mui/icons-material/Clear'
import { TORRENT_CATEGORIES } from 'components/categories'
import FilterByCategory from 'components/FilterByCategory'

import { AppSidebarStyle } from './style'

const Sidebar = ({ isDrawerOpen, setIsDonationDialogOpen, isOffline, isLoading, setGlobalFilterCategory }) => {
  const { t } = useTranslation()

  return (
    <AppSidebarStyle isDrawerOpen={isDrawerOpen}>
      <List>
        <AddDialogButton isOffline={isOffline} isLoading={isLoading} />
        <SearchDialogButton isOffline={isOffline} isLoading={isLoading} />

        <RemoveAll isOffline={isOffline} isLoading={isLoading} />
      </List>

      <Divider />

      <List>
        <FilterByCategory
          key='all'
          categoryKey='all'
          categoryName={t('All')}
          icon={<CheckIcon />}
          setGlobalFilterCategory={setGlobalFilterCategory}
        />
        {TORRENT_CATEGORIES.map(category => (
          <FilterByCategory
            key={category.key}
            categoryKey={category.key}
            categoryName={t(category.name)}
            icon={category.icon}
            setGlobalFilterCategory={setGlobalFilterCategory}
          />
        ))}
        <FilterByCategory
          key='uncategorized'
          categoryKey=''
          categoryName={t('Uncategorized')}
          icon={<ClearIcon />}
          setGlobalFilterCategory={setGlobalFilterCategory}
        />
      </List>

      <Divider />

      <List>
        <SettingsDialog isOffline={isOffline} isLoading={isLoading} />

        <AboutDialog />

        <ListItem button onClick={() => setIsDonationDialogOpen(true)}>
          <ListItemIcon>
            <CreditCardIcon />
          </ListItemIcon>

          <ListItemText primary={t('Donate')} />
        </ListItem>

        <CloseServer isOffline={isOffline} isLoading={isLoading} />
      </List>
    </AppSidebarStyle>
  )
}

export default memo(Sidebar)
