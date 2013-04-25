# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
from marvin.base import CloudStackEntity
from marvin.cloudstackAPI import listProjectInvitations
from marvin.cloudstackAPI import updateProjectInvitation
from marvin.cloudstackAPI import deleteProjectInvitation

class ProjectInvitation(CloudStackEntity.CloudStackEntity):


    def __init__(self, items):
        self.__dict__.update(items)


    @classmethod
    def list(self, apiclient, **kwargs):
        cmd = listProjectInvitations.listProjectInvitationsCmd()
        [setattr(cmd, key, value) for key,value in kwargs.iteritems()]
        projectinvitation = apiclient.listProjectInvitations(cmd)
        return map(lambda e: ProjectInvitation(e.__dict__), projectinvitation)


    def update(self, apiclient, projectid, **kwargs):
        cmd = updateProjectInvitation.updateProjectInvitationCmd()
        cmd.id = self.id
        cmd.projectid = projectid
        [setattr(cmd, key, value) for key,value in kwargs.iteritems()]
        projectinvitation = apiclient.updateProjectInvitation(cmd)
        return projectinvitation


    def delete(self, apiclient, **kwargs):
        cmd = deleteProjectInvitation.deleteProjectInvitationCmd()
        cmd.id = self.id
        [setattr(cmd, key, value) for key,value in kwargs.iteritems()]
        projectinvitation = apiclient.deleteProjectInvitation(cmd)
        return projectinvitation