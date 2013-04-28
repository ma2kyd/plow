
#######################
# Project
#
cdef inline Project initProject(ProjectT& p):
    cdef Project project = Project()
    project.setProject(p)
    return project


cdef class Project:
    """
    A Project 

    :var ``id``: str 
    :var code: str 
    :var title: str 
    :var isActive: bool 
    
    """
    cdef ProjectT project

    cdef setProject(self, ProjectT& proj):
        self.project = proj

    property id:
        def __get__(self): return self.project.id

    property code:
        def __get__(self): return self.project.code

    property title:
        def __get__(self): return self.project.title

    property isActive:
        def __get__(self): return self.project.isActive

    cpdef refresh(self):
        """
        Refresh the attributes from the server
        """
        conn().proxy().getProject(self.project, self.project.id)

    def get_folders(self):
        """
        Get the folders for this project 

        :returns: list[:class:`.Folder`]
        """
        cdef:
            vector[FolderT] folders
            FolderT foldT 
            list results

        try:
            conn().proxy().getFolders(folders, self.project.id)
        except:
            results = []
            return results

        results = [initFolder(foldT) for foldT in folders]
        return results

    def set_active(self, bint active):
        """
        Set the active state of the Project 

        :param active: bool
        """
        set_project_active(self, active)
        self.project.isActive = active

cpdef inline get_project(Guid& guid):
    """
    Get a Project by id 

    :param guid: str - project id 
    :returns: :class:`.Project`
    """
    cdef: 
        ProjectT projT 
        Project project

    conn().proxy().getProject(projT, guid)
    project = initProject(projT)
    return project


cpdef inline get_project_by_code(string code):
    """
    Look up a Project by its code

    :param code: str 
    :returns: :class:`.Project`
    """
    cdef: 
        ProjectT projT 
        Project project

    conn().proxy().getProjectByCode(projT, code)
    project = initProject(projT)
    return project


def get_projects():
    """
    Get a list of all Projects 

    :returns: list[:class:`.Project`]
    """
    cdef:
        vector[ProjectT] projects 
        ProjectT projT
        list results

    try:
        conn().proxy().getProjects(projects)
    except:
        results = []
        return results

    results = [initProject(projT) for projT in projects] 
    return results

def get_active_projects():
    """
    Return a list of only active Projects 

    :returns: list[:class:`.Project`]
    """
    cdef:
        vector[ProjectT] projects 
        ProjectT projT
        list results

    try:
        conn().proxy().getActiveProjects(projects)
    except:
        results = []
        return results

    results = [initProject(projT) for projT in projects] 
    return results    

def create_project(string title, string code):
    """
    Create a new Project with a title and code 

    :param title: str - A full project title  
    :param code: str - A short code to indentify the project 
    :returns: :class:`.Project`
    """
    cdef ProjectT projT
    cdef Project proj 
    conn().proxy().createProject(projT, title, code)
    proj = initProject(projT)
    return proj

cpdef inline set_project_active(Project project, bint active):
    """
    Set a project to be active 

    :param project: :class:`.Project`
    :param active: bool 
    """
    conn().proxy().setProjectActive(project.id, active)


 