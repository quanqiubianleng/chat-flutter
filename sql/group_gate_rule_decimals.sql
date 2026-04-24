-- 与 conversation 服务一致：为 group_gate_rule 增加 decimals 列（执行一次）
-- 错误 Unknown column 'decimals' 即未执行本脚本。
ALTER TABLE `group_gate_rule`
  ADD COLUMN `decimals` INT NOT NULL DEFAULT 0 COMMENT 'ERC20/原生小数位；0 表示按合约推断' AFTER `min_amount`;
