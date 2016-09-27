{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
module Reflex.Dom.Builder.InputDisabled where

import Control.Lens
import Control.Monad.Fix
import Control.Monad.Ref
import Control.Monad.Trans
import Control.Monad.Trans.Control
import qualified Data.Map as Map
import Foreign.JavaScript.TH
import Reflex
import Reflex.Deletable.Class
import Reflex.Dom.Builder.Class
import Reflex.Host.Class

-- | A DomBuilder transformer that disables all 'inputElement's,
-- 'textAreaElement's, and 'selectElement's by adding the "disabled" HTML
-- attribute.  Note that 'element's that happen to have "input", "textarea", or
-- "select" as their tag will NOT be disabled.
newtype InputDisabledT m a = InputDisabledT { runInputDisabledT :: m a } deriving (Functor, Applicative, Monad, MonadAtomicRef, MonadFix, MonadIO)

deriving instance MonadSample t m => MonadSample t (InputDisabledT m)
deriving instance MonadHold t m => MonadHold t (InputDisabledT m)

instance MonadTrans InputDisabledT where
  lift = InputDisabledT

instance MonadTransControl InputDisabledT where
  type StT InputDisabledT a = a
  liftWith f = InputDisabledT $ f runInputDisabledT
  restoreT = InputDisabledT

instance MonadRef m => MonadRef (InputDisabledT m) where
  type Ref (InputDisabledT m) = Ref m
  newRef = lift . newRef
  readRef = lift . readRef
  writeRef ref = lift . writeRef ref

instance PerformEvent t m => PerformEvent t (InputDisabledT m) where
  type Performable (InputDisabledT m) = Performable m
  performEvent_ = lift . performEvent_
  performEvent = lift . performEvent

disableElementConfig :: Reflex t => ElementConfig er t m -> ElementConfig er t m
disableElementConfig cfg = cfg
  { _elementConfig_initialAttributes = Map.insert "disabled" "disabled" $ _elementConfig_initialAttributes cfg
  , _elementConfig_modifyAttributes = Map.delete "disabled" <$> _elementConfig_modifyAttributes cfg
  }

instance Deletable t m => Deletable t (InputDisabledT m) where
  deletable d = liftThrough $ deletable d

instance PostBuild t m => PostBuild t (InputDisabledT m) where
  getPostBuild = lift getPostBuild

deriving instance TriggerEvent t m => TriggerEvent t (InputDisabledT m)

instance MonadReflexCreateTrigger t m => MonadReflexCreateTrigger t (InputDisabledT m) where
  newEventWithTrigger = lift . newEventWithTrigger
  newFanEventWithTrigger f = lift $ newFanEventWithTrigger f

instance DomBuilder t m => DomBuilder t (InputDisabledT m) where
  type DomBuilderSpace (InputDisabledT m) = DomBuilderSpace m
  placeholder cfg = lift $ placeholder $ cfg
    & placeholderConfig_insertAbove %~ fmap runInputDisabledT
  inputElement cfg = lift $ inputElement $ cfg
    { _inputElementConfig_elementConfig = liftElementConfig $ disableElementConfig $ _inputElementConfig_elementConfig cfg
    }
  textAreaElement cfg = lift $ textAreaElement $ cfg
    { _textAreaElementConfig_elementConfig = liftElementConfig $ disableElementConfig $ _textAreaElementConfig_elementConfig cfg
    }
  selectElement cfg child = do
    let cfg' = cfg
          { _selectElementConfig_elementConfig = liftElementConfig $ disableElementConfig $ _selectElementConfig_elementConfig cfg
          }
    lift $ selectElement cfg' $ runInputDisabledT child

instance HasWebView m => HasWebView (InputDisabledT m) where
  type WebViewPhantom (InputDisabledT m) = WebViewPhantom m
  askWebView = lift askWebView

instance HasJS js m => HasJS js (InputDisabledT m) where
  type JSM (InputDisabledT m) = JSM m
  liftJS = lift . liftJS
