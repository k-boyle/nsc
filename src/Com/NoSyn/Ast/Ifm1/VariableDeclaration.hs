module Com.NoSyn.Ast.Ifm1.VariableDeclaration where

import qualified Com.NoSyn.Ast.If.IfElement as IfElement
import qualified Com.NoSyn.Ast.If.VariableDeclaration as IfVariableDeclaration
import Com.NoSyn.Ast.Traits.IfElementGeneratable

data VariableDeclaration =
    IfVariableDeclaration IfVariableDeclaration.VariableDeclaration
    deriving Show

instance IfElementGeneratable VariableDeclaration where
    generateIfElement _ (IfVariableDeclaration a) =
        return $ IfElement.IfVariableDeclaration a