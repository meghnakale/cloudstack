-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing,
-- software distributed under the License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
-- KIND, either express or implied.  See the License for the
-- specific language governing permissions and limitations
-- under the License.

--;
-- Schema upgrade from 4.2.0 to 4.3.0;
--;

-- Disable foreign key checking
SET foreign_key_checks = 0;

ALTER TABLE `cloud`.`async_job` ADD COLUMN `related` CHAR(40) NOT NULL;
ALTER TABLE `cloud`.`async_job` DROP COLUMN `session_key`;
ALTER TABLE `cloud`.`async_job` DROP COLUMN `job_cmd_originator`;
ALTER TABLE `cloud`.`async_job` DROP COLUMN `callback_type`;
ALTER TABLE `cloud`.`async_job` DROP COLUMN `callback_address`;

ALTER TABLE `cloud`.`async_job` ADD COLUMN `job_type` VARCHAR(32);
ALTER TABLE `cloud`.`async_job` ADD COLUMN `job_dispatcher` VARCHAR(64);
ALTER TABLE `cloud`.`async_job` ADD COLUMN `job_executing_msid` bigint;
ALTER TABLE `cloud`.`async_job` ADD COLUMN `job_pending_signals` int(10) NOT NULL DEFAULT 0;

ALTER TABLE `cloud`.`vm_instance` ADD COLUMN `power_state` VARCHAR(74) DEFAULT 'PowerUnknown';
ALTER TABLE `cloud`.`vm_instance` ADD COLUMN `power_state_update_time` DATETIME;
ALTER TABLE `cloud`.`vm_instance` ADD COLUMN `power_state_update_count` INT DEFAULT 0;
ALTER TABLE `cloud`.`vm_instance` ADD COLUMN `power_host` bigint unsigned;
ALTER TABLE `cloud`.`vm_instance` ADD CONSTRAINT `fk_vm_instance__power_host` FOREIGN KEY (`power_host`) REFERENCES `cloud`.`host`(`id`);

CREATE TABLE `cloud`.`vm_work_job` (
  `id` bigint unsigned UNIQUE NOT NULL,
  `step` char(32) NOT NULL COMMENT 'state',
  `vm_type` char(32) NOT NULL COMMENT 'type of vm',
  `vm_instance_id` bigint unsigned NOT NULL COMMENT 'vm instance',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_vm_work_job__instance_id` FOREIGN KEY (`vm_instance_id`) REFERENCES `vm_instance`(`id`) ON DELETE CASCADE,
  INDEX `i_vm_work_job__vm`(`vm_type`, `vm_instance_id`),
  INDEX `i_vm_work_job__step`(`step`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `cloud`.`async_job_journal` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `job_id` bigint unsigned NOT NULL,
  `journal_type` varchar(32),
  `journal_text` varchar(1024) COMMENT 'journal descriptive informaton',
  `journal_obj` varchar(1024) COMMENT 'journal strutural information, JSON encoded object',
  `created` datetime NOT NULL COMMENT 'date created',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_async_job_journal__job_id` FOREIGN KEY (`job_id`) REFERENCES `async_job`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `cloud`.`async_job_join_map` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `job_id` bigint unsigned NOT NULL,
  `join_job_id` bigint unsigned NOT NULL,
  `join_status` int NOT NULL,
  `join_result` varchar(1024),
  `join_msid` bigint,
  `complete_msid` bigint,
  `sync_source_id` bigint COMMENT 'upper-level job sync source info before join',
  `wakeup_handler` varchar(64),
  `wakeup_dispatcher` varchar(64),
  `wakeup_interval` bigint NOT NULL DEFAULT 3000 COMMENT 'wakeup interval in seconds',
  `created` datetime NOT NULL,
  `last_updated` datetime,
  `next_wakeup` datetime,
  `expiration` datetime,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_async_job_join_map__job_id` FOREIGN KEY (`job_id`) REFERENCES `async_job`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_async_job_join_map__join_job_id` FOREIGN KEY (`join_job_id`) REFERENCES `async_job`(`id`),
  CONSTRAINT `fk_async_job_join_map__join` UNIQUE (`job_id`, `join_job_id`),
  INDEX `i_async_job_join_map__join_job_id`(`join_job_id`),
  INDEX `i_async_job_join_map__created`(`created`),
  INDEX `i_async_job_join_map__last_updated`(`last_updated`),
  INDEX `i_async_job_join_map__next_wakeup`(`next_wakeup`),
  INDEX `i_async_job_join_map__expiration`(`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE `cloud`.`configuration` ADD COLUMN `default_value` VARCHAR(4095) COMMENT 'Default value for a configuration parameter';
ALTER TABLE `cloud`.`configuration` ADD COLUMN `updated` datetime COMMENT 'Time this was updated by the server. null means this row is obsolete.';
ALTER TABLE `cloud`.`configuration` ADD COLUMN `scope` VARCHAR(255) DEFAULT NULL COMMENT 'Can this parameter be scoped';
ALTER TABLE `cloud`.`configuration` ADD COLUMN `is_dynamic` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Can the parameter be change dynamically without restarting the server';

UPDATE `cloud`.`configuration` SET `default_value` = `value`;

#Upgrade the offerings and template table to have actual remove and states
ALTER TABLE `cloud`.`disk_offering` ADD COLUMN `state` CHAR(40) NOT NULL DEFAULT 'Active' COMMENT 'state for disk offering';

UPDATE `cloud`.`disk_offering` SET `state`='Inactive' WHERE `removed` IS NOT NULL;
UPDATE `cloud`.`disk_offering` SET `removed`=NULL;

UPDATE `cloud`.`vm_template` SET `state`='Inactive' WHERE `removed` IS NOT NULL;
UPDATE `cloud`.`vm_template` SET `state`='Active' WHERE `removed` IS NULL;
UPDATE `cloud`.`vm_template` SET `removed`=NULL;

DROP VIEW IF EXISTS `cloud`.`disk_offering_view`;
CREATE VIEW `cloud`.`disk_offering_view` AS
    select
        disk_offering.id,
        disk_offering.uuid,
        disk_offering.name,
        disk_offering.display_text,
        disk_offering.disk_size,
        disk_offering.min_iops,
        disk_offering.max_iops,
        disk_offering.created,
        disk_offering.tags,
        disk_offering.customized,
        disk_offering.customized_iops,
        disk_offering.removed,
        disk_offering.use_local_storage,
        disk_offering.system_use,
        disk_offering.bytes_read_rate,
        disk_offering.bytes_write_rate,
        disk_offering.iops_read_rate,
        disk_offering.iops_write_rate,
        disk_offering.sort_key,
        disk_offering.type,
		disk_offering.display_offering,
        domain.id domain_id,
        domain.uuid domain_uuid,
        domain.name domain_name,
        domain.path domain_path
    from
        `cloud`.`disk_offering`
            left join
        `cloud`.`domain` ON disk_offering.domain_id = domain.id
	where
		disk_offering.state='ACTIVE';

DROP VIEW IF EXISTS `cloud`.`service_offering_view`;
CREATE VIEW `cloud`.`service_offering_view` AS
    select 
        service_offering.id,
        disk_offering.uuid,
        disk_offering.name,
        disk_offering.display_text,
        disk_offering.created,
        disk_offering.tags,
        disk_offering.removed,
        disk_offering.use_local_storage,
        disk_offering.system_use,
        disk_offering.bytes_read_rate,
        disk_offering.bytes_write_rate,
        disk_offering.iops_read_rate,
        disk_offering.iops_write_rate,
        service_offering.cpu,
        service_offering.speed,
        service_offering.ram_size,
        service_offering.nw_rate,
        service_offering.mc_rate,
        service_offering.ha_enabled,
        service_offering.limit_cpu_use,
        service_offering.host_tag,
        service_offering.default_use,
        service_offering.vm_type,
        service_offering.sort_key,
        service_offering.is_volatile,
        service_offering.deployment_planner,
        domain.id domain_id,
        domain.uuid domain_uuid,
        domain.name domain_name,
        domain.path domain_path
    from
        `cloud`.`service_offering`
            inner join
        `cloud`.`disk_offering` ON service_offering.id = disk_offering.id
            left join
        `cloud`.`domain` ON disk_offering.domain_id = domain.id
	where
		disk_offering.state='Active';
		
DROP VIEW IF EXISTS `cloud`.`template_view`;
CREATE VIEW `cloud`.`template_view` AS
    select 
        vm_template.id,
        vm_template.uuid,
        vm_template.unique_name,
        vm_template.name,
        vm_template.public,
        vm_template.featured,
        vm_template.type,
        vm_template.hvm,
        vm_template.bits,
        vm_template.url,
        vm_template.format,
        vm_template.created,
        vm_template.checksum,
        vm_template.display_text,
        vm_template.enable_password,
        vm_template.dynamically_scalable,
        vm_template.guest_os_id,
        guest_os.uuid guest_os_uuid,
        guest_os.display_name guest_os_name,
        vm_template.bootable,
        vm_template.prepopulate,
        vm_template.cross_zones,
        vm_template.hypervisor_type,
        vm_template.extractable,
        vm_template.template_tag,
        vm_template.sort_key,
        vm_template.removed,
        vm_template.enable_sshkey,
        source_template.id source_template_id,
        source_template.uuid source_template_uuid,
        account.id account_id,
        account.uuid account_uuid,
        account.account_name account_name,
        account.type account_type,
        domain.id domain_id,
        domain.uuid domain_uuid,
        domain.name domain_name,
        domain.path domain_path,
        projects.id project_id,
        projects.uuid project_uuid,
        projects.name project_name,        
        data_center.id data_center_id,
        data_center.uuid data_center_uuid,
        data_center.name data_center_name,
        launch_permission.account_id lp_account_id,
        template_store_ref.store_id,
		image_store.scope as store_scope,
        template_store_ref.state,
        template_store_ref.download_state,
        template_store_ref.download_pct,
        template_store_ref.error_str,
        template_store_ref.size,
        template_store_ref.destroyed,
        template_store_ref.created created_on_store,
        vm_template_details.name detail_name,
        vm_template_details.value detail_value,
        resource_tags.id tag_id,
        resource_tags.uuid tag_uuid,
        resource_tags.key tag_key,
        resource_tags.value tag_value,
        resource_tags.domain_id tag_domain_id,
        resource_tags.account_id tag_account_id,
        resource_tags.resource_id tag_resource_id,
        resource_tags.resource_uuid tag_resource_uuid,
        resource_tags.resource_type tag_resource_type,
        resource_tags.customer tag_customer,
		CONCAT(vm_template.id, '_', IFNULL(data_center.id, 0)) as temp_zone_pair
    from
        `cloud`.`vm_template`
            inner join
        `cloud`.`guest_os` ON guest_os.id = vm_template.guest_os_id        
            inner join
        `cloud`.`account` ON account.id = vm_template.account_id
            inner join
        `cloud`.`domain` ON domain.id = account.domain_id
            left join
        `cloud`.`projects` ON projects.project_account_id = account.id    
            left join
        `cloud`.`vm_template_details` ON vm_template_details.template_id = vm_template.id         
            left join
        `cloud`.`vm_template` source_template ON source_template.id = vm_template.source_template_id    
            left join
        `cloud`.`template_store_ref` ON template_store_ref.template_id = vm_template.id and template_store_ref.store_role = 'Image'
            left join
        `cloud`.`image_store` ON image_store.removed is NULL AND template_store_ref.store_id is not NULL AND image_store.id = template_store_ref.store_id 
        	left join
        `cloud`.`template_zone_ref` ON template_zone_ref.template_id = vm_template.id AND template_store_ref.store_id is NULL AND template_zone_ref.removed is null    
            left join
        `cloud`.`data_center` ON (image_store.data_center_id = data_center.id OR template_zone_ref.zone_id = data_center.id)
            left join
        `cloud`.`launch_permission` ON launch_permission.template_id = vm_template.id
            left join
        `cloud`.`resource_tags` ON resource_tags.resource_id = vm_template.id
            and (resource_tags.resource_type = 'Template' or resource_tags.resource_type='ISO')
    where
        vm_template.state='Active';	
        
-- ACL DB schema        
CREATE TABLE `cloud`.`acl_group` (
  `id` bigint unsigned NOT NULL UNIQUE auto_increment,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) default NULL,
  `uuid` varchar(40),
  `domain_id` bigint unsigned NOT NULL,  
  `removed` datetime COMMENT 'date the group was removed',
  `created` datetime COMMENT 'date the group was created',
  PRIMARY KEY  (`id`),
  INDEX `i_acl_group__removed`(`removed`),
  CONSTRAINT `uc_acl_group__uuid` UNIQUE (`uuid`)  
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `cloud`.`acl_group_account_map` (
  `id` bigint unsigned NOT NULL auto_increment,
  `group_id` bigint unsigned NOT NULL,
  `account_id` bigint unsigned NOT NULL,
  `removed` datetime COMMENT 'date the account was removed from the group',
  `created` datetime COMMENT 'date the account was assigned to the group',  
  PRIMARY KEY  (`id`),
  CONSTRAINT `fk_acl_group_vm_map__group_id` FOREIGN KEY(`group_id`) REFERENCES `acl_group` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_acl_group_vm_map__account_id` FOREIGN KEY(`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;        

CREATE TABLE `cloud`.`acl_role` (
  `id` bigint unsigned NOT NULL UNIQUE auto_increment,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) default NULL,  
  `uuid` varchar(40),
  `parent_role_id` bigint unsigned DEFAULT 0,
  `domain_id` bigint unsigned NOT NULL,  
  `removed` datetime COMMENT 'date the role was removed',
  `created` datetime COMMENT 'date the role was created',
  PRIMARY KEY  (`id`),
  INDEX `i_acl_role__removed`(`removed`),
  CONSTRAINT `uc_acl_role__uuid` UNIQUE (`uuid`),  
  CONSTRAINT `fk_acl_role__parent_role_id` FOREIGN KEY(`parent_role_id`) REFERENCES `acl_role` (`id`) ON DELETE CASCADE  
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `cloud`.`acl_group_role_map` (
  `id` bigint unsigned NOT NULL auto_increment,
  `group_id` bigint unsigned NOT NULL,
  `role_id` bigint unsigned NOT NULL,
  `removed` datetime COMMENT 'date the role was revoked from the group',
  `created` datetime COMMENT 'date the role was granted to the group',   
  PRIMARY KEY  (`id`),
  CONSTRAINT `fk_acl_group_role_map__group_id` FOREIGN KEY(`group_id`) REFERENCES `acl_group` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_acl_group_role_map__role_id` FOREIGN KEY(`role_id`) REFERENCES `acl_role` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;        


INSERT IGNORE INTO `cloud`.`acl_role` (id, name, description, uuid, domain_id, created) VALUES (1,'NORMAL', 'Domain user role', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_role` (id, name, description, uuid, domain_id, created) VALUES (2, 'ADMIN', 'Root admin role', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_role` (id, name, description, uuid, domain_id, created) VALUES (3, 'DOMAIN_ADMIN', 'Domain admin role', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_role` (id, name, description, uuid, domain_id, created) VALUES (4, 'RESOURCE_DOMAIN_ADMIN', 'Resource domain admin role', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_role` (id, name, description, uuid, domain_id, created) VALUES (5, 'READ_ONLY_ADMIN', 'Read only admin role', UUID(), 1, Now());

INSERT IGNORE INTO `cloud`.`acl_group` (id, name, description, uuid, domain_id, created) VALUES (1, 'NORMAL', 'Domain user group', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_group` (id, name, description, uuid, domain_id, created) VALUES (2, 'ADMIN', 'Root admin group', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_group` (id, name, description, uuid, domain_id, created) VALUES (3, 'DOMAIN_ADMIN', 'Domain admin group', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_group` (id, name, description, uuid, domain_id, created) VALUES (4, 'RESOURCE_DOMAIN_ADMIN', 'Resource domain admin group', UUID(), 1, Now());
INSERT IGNORE INTO `cloud`.`acl_group` (id, name, description, uuid, domain_id, created) VALUES (5, 'READ_ONLY_ADMIN', 'Read only admin group', UUID(), 1, Now());

CREATE TABLE `cloud`.`acl_api_permission` (
  `id` bigint unsigned NOT NULL UNIQUE auto_increment,
  `role_id` bigint unsigned NOT NULL,
  `api` varchar(255) NOT NULL,
  `removed` datetime COMMENT 'date the permission was revoked',
  `created` datetime COMMENT 'date the permission was granted',  
  PRIMARY KEY  (`id`),
  CONSTRAINT `fk_acl_api_permission__role_id` FOREIGN KEY(`role_id`) REFERENCES `acl_role` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `cloud`.`acl_entity_permission` (
  `id` bigint unsigned NOT NULL UNIQUE auto_increment,
  `group_id` bigint unsigned NOT NULL,
  `entity_type` varchar(100) NOT NULL,
  `entity_id` bigint unsigned NOT NULL,
  `entity_uuid` varchar(40),  
  `access_type` varchar(40) NOT NULL,  
  `removed` datetime COMMENT 'date the permission was revoked',
  `created` datetime COMMENT 'date the permission was granted',   
  PRIMARY KEY  (`id`),
  CONSTRAINT `fk_acl_entity_permission__group_id` FOREIGN KEY(`group_id`) REFERENCES `acl_group` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `cloud`.`acl_role_permission` (
  `id` bigint unsigned NOT NULL UNIQUE auto_increment,
  `role_id` bigint unsigned NOT NULL,
  `entity_type` varchar(100) NOT NULL,
  `access_type` varchar(40) NOT NULL,
  `permission` int(1) unsigned NOT NULL COMMENT '1 allowed, 0 for denied',
  PRIMARY KEY  (`id`),
  CONSTRAINT `fk_acl_role_permission___role_id` FOREIGN KEY(`role_id`) REFERENCES `acl_role` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP VIEW IF EXISTS `cloud`.`acl_role_view`;
CREATE VIEW `cloud`.`acl_role_view` AS
    select 
        acl_role.id id,
        acl_role.uuid uuid,        
        acl_role.name name,
        acl_role.description description,
        parent_role.id parent_role_id,
        parent_role.uuid parent_role_uuid,
        parent_role.name parent_role_name,
        acl_role.removed removed,
        acl_role.created created,
        domain.id domain_id,
        domain.uuid domain_uuid,
        domain.name domain_name,
        domain.path domain_path,
        acl_api_permission.api api_name
    from
        `cloud`.`acl_role`
            inner join
        `cloud`.`domain` ON acl_role.domain_id = domain.id
            left join
        `cloud`.`acl_role` parent_role on parent_role.id = acl_role.parent_role_id    
            left join
        `cloud`.`acl_api_permission` ON acl_role.id = acl_api_permission.role_id;
 
 
DROP VIEW IF EXISTS `cloud`.`acl_group_view`;
CREATE VIEW `cloud`.`acl_group_view` AS
    select 
        acl_group.id id,
        acl_group.uuid uuid,        
        acl_group.name name,
        acl_group.description description,
        acl_group.removed removed,
        acl_group.created created,
        domain.id domain_id,
        domain.uuid domain_uuid,
        domain.name domain_name,
        domain.path domain_path,
        acl_role.id role_id,
        acl_role.uuid role_uuid,
        acl_role.name role_name,
        account.id account_id,
        account.uuid account_uuid,
        account.account_name account_name,
        acl_entity_permission.entity_id entity_id,
        acl_entity_permission.entity_uuid entity_uuid,
        acl_entity_permission.entity_type entity_type,
        acl_entity_permission.access_type access_type
    from
        `cloud`.`acl_group`
            inner join
        `cloud`.`domain` ON acl_group.domain_id = domain.id
            left join
        `cloud`.`acl_group_role_map` on acl_group.id = acl_group_role_map.group_id  
            left join         
        `cloud`.`acl_role` on acl_group_role_map.role_id = acl_role.id    
            left join
        `cloud`.`acl_group_account_map` ON acl_group.id = acl_group_account_map.group_id
            left join
        `cloud`.`account` ON acl_group_account_map.account_id = account.id
            left join
         `cloud`.`acl_entity_permission` ON acl_group.id = acl_entity_permission.group_id;                         
 