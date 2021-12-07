function Data = ParticleFilter(Options)

    close all
    addpath('./affichage/');
    addpath('./data/');
    addpath('./likelihood/');
    addpath('./redistribution (resampling)/');
    addpath('./robot/');
    addpath('./selection/');
    addpath('./sensors/');
    addpath('./utilities/');
    
%% initialization of parameters 
    %load map data
    load('bat5_Obstacles_detect_redone140220.mat');
    
    %start tracking time
    T_Debut=tic;
    
    global Indice_ % to be used in redistribution
    global FlagRedistribution % to be used in redistribution (may be used the same way as Indice_ check later!!!)
    global N ;% Nombre de particules
    global idx_seg ;% indice du segment courant
    global test_orientation; % pour tester si on doit faire une translation(==0) ou rotation(==1)
    global Robot;
    global Particles; %position des particules
    global PoseEstime;



    
    N=Options.NParticles;  
    idx_seg=1;
    test_orientation=0;
    maxIteration = 10000;
    test_mesure=0; % indice utilisee pour effectuer une mesure pour plusieurs iterations
    Portee=4; % portee des capteurs
    fin_trajectoire=0; % test pour verifier que le robot a termine sa trajectoire 
    ObstaclesMobiles=[];

    t_iteration = NaN(1,maxIteration); % vecteur contient le temps de chaque iteration  
    N_Particles=NaN(1,maxIteration);  % vecteur contient le nombre des particules de chaque iteration
    iteration=NaN(1,maxIteration);
    vecteur_Robot=NaN(3,maxIteration);
    vecteur_estimation=NaN(3,maxIteration);
    vecteur_erreur=[];
    vecteur_particles=[];
    vecteur_Poids = [];
    vecteur_incertitude_x=[];
    vecteur_incertitude_y=[];
    vecteur_incertitude_theta=[];
    vecteur_Tconvergence=[];
    vecteur_It_convergence=[];
    iteration_convergence =0;
    T_convergence = 0;

    indice_controle=0; % indice pour effectuer ou non le controle
    FlagRedistribution = 0 ; 
    Indice_ = 1 ;





%% generation des trajectoire : calcule les points de passages du robot et la vitesse correspond a  chaque segment de la trajectoire   
    Start=Options.StartPoint; % point de dépat du robot 
    End = Options.EndPoint;
    Robot.x=Start(1);
    Robot.y=Start(2);
    Robot.theta=-pi/2;
    
    

%% generation des particules dans l'environement  

%     %generetion des particles autour du robot :
%     PP = trajectoryGenerator(Options.NPP,Obstacles,Start,End,10,Options.plot);
    PP = squeeze(Options.PP);
    v = Options.MaxSpeed*ones(length(PP),1);
    if Options.plot
        figure(10)
        plot(PP(1,:),PP(2,:),'*k')
        hold on
        plot(PP(1,:),PP(2,:),'k')
    end
    clear Particles
    particles1=Particles_generator(26.5747,29.02,-0.269984,56,-pi,pi,floor(N/2),Obstacles);
    particles2=Particles_generator(-5,26.5747,-0.269984,11.53,-pi,pi,N-floor(N/2),Obstacles);
    particles=[particles1,particles2];
    Particles.x=particles(1,:);
    Particles.y=particles(2,:);
    Particles.theta=particles(3,:);


    % la definition du nombre de capteurs et de leurs angles :
    theta=linspace(-pi,pi,Options.NR);  


 %% initialisation d'affichage : 
    if Options.plot
        figure(10)
        plot_Environement(Obstacles,10);%affichage de l'environnement
        robPoints = plot(Robot.x,Robot.y,'o');
        particPoints=plot(Particles.x,Particles.y,'.r');
    end
    


indice_controle=1;
%% boucle du filtrage:
    i=0;
    
    while(fin_trajectoire == 0)
        temps_debut_iteration=tic;
        test_mesure=test_mesure+1;
        i=i+1;

        % initialisation des poids :
        Poids = ones(N,1)/N;

        if (indice_controle==1)

            % controle du robot :
            Robot = controle(Robot,PP,v,0);
            % affichage du robot :
            if Options.plot
                set(robPoints,'XData',Robot.x);
                set(robPoints,'YData',Robot.y);
            end

            % controle des particules :
            for j=1:N
                if (idx_seg == (Options.NPP+2))
                    break
                end
                P.x=Particles.x(j);
                P.y=Particles.y(j);
                P.theta=Particles.theta(j);
                P=controle(P,PP,v,0);
                Particles.x(j)=P.x;
                Particles.y(j)=P.y;
                Particles.theta(j)=P.theta;
            end

            % affichage des particules :
            if Options.plot
                hold on 
                set(particPoints,'XData',Particles.x);
                set(particPoints,'YData',Particles.y);
            end
        end


%% measurement step
        % prendre les mesures du robot et des particules :
        Debut_mesure=tic; % variable pour calculer le temps du mesure 

        if(test_mesure==3) 
            % mesures du robot :
            rho_rob=Mesure_act(Options.SensorsType,Portee,Robot.x,Robot.y,Robot.theta,theta,Obstacles,ObstaclesMobiles,1,1);
            for k=1:N
                % mesures des particules :
                rho_particles=Mesure_act(Options.SensorsType,Portee,Particles.x(k),Particles.y(k),Particles.theta(k),theta,Obstacles,ObstaclesMobiles,0,1);
                
                %likelihood step
                Poids(k)=likelihood(Options.Likelihood,rho_rob,rho_particles);
            end
            Temps_mesure=toc(Debut_mesure); % temps pour chaque mesure 
%% selection step
            iNextGeneration = selection(Options.Selection,Poids,N);

%% check for convergance
            % calcule de l'ecart-type des particules :
            SdX=sqrt(var(Particles.x(iNextGeneration)));
            SdY=sqrt(var(Particles.y(iNextGeneration)));
            SdTheta=sqrt(var(Particles.theta(iNextGeneration)));

            % si l'ecart-type soit inferieur Ã  certin seulle <=> les particules
            % converge :
            if(SdX<7 && SdY<7 && SdTheta<2)
                % la psition estimee du robot = la moyenne des particules :
                %PoseEstime.x=mean(Particles.x(iNextGeneration));
                %PoseEstime.y=mean(Particles.y(iNextGeneration));
                %PoseEstime.theta=mean(Particles.theta(iNextGeneration));
                % la psition estimee du robot = la somme particules*poids
                PoseEstime.x = Poids*Particles.x(iNextGeneration);
                PoseEstime.y = Poids*Particles.y(iNextGeneration);
                PoseEstime.theta = Poids*Particles.theta(iNextGeneration);
                % information sur l'erreur 
                Erreur.x=Robot.x-PoseEstime.x;
                Erreur.y=Robot.y-PoseEstime.y;
                Erreur.theta=Robot.theta-PoseEstime.theta;
                vecteur_erreur=[vecteur_erreur,[Erreur.x;Erreur.y;Erreur.theta]];


                % information sur l'incertitude
                incertitude_x(1) = min(Particles.x(iNextGeneration));
                incertitude_x(2) = max(Particles.x(iNextGeneration));
                incertitude_y(1) = min(Particles.y(iNextGeneration));
                incertitude_y(2) = max(Particles.y(iNextGeneration));
                incertitude_theta(1) = min(Particles.theta(iNextGeneration));
                incertitude_theta(2) = max(Particles.theta(iNextGeneration));

                vecteur_incertitude_x = [vecteur_incertitude_x, incertitude_x'];
                vecteur_incertitude_y = [vecteur_incertitude_y, incertitude_y'];
                vecteur_incertitude_theta = [vecteur_incertitude_theta, incertitude_theta'];

                vecteur_estimation=[vecteur_estimation,[PoseEstime.x;PoseEstime.y;PoseEstime.theta]];



                % redistribution
                % si les particules convergent vers une position autre que la position du robot :
                % On redistribue les particules sur toute la carte 
                if ~exist('OldParticles','var')
                    OldParticles.x = [];
                    OldParticles.y = [];
                end
                if ~exist('OldRobot','var')
                    OldRobot.x = [];
                    OldRobot.y = [];
                end
                
                [Particles,OldParticles,OldRobot,vecteur_Tconvergence,vecteur_It_convergence] = resampling(Particles,Options.Distribution,Obstacles,OldRobot,OldParticles,Options.NParticles,T_Debut,i,vecteur_Tconvergence,vecteur_It_convergence,SdX,SdY,SdTheta);

                
            end

            if  Indice_ == 1
                Particles=testInext(iNextGeneration,Particles,Obstacles);
            else 
                Indice_ = 1;
            end
            test_mesure=0;
        end

        indice_controle=1;
        drawnow;
        
        % si on arrive au dernier segment on finit le controle  
        if (idx_seg == (Options.NPP+2) || idx_seg > 4)
            fin_trajectoire = 1;
            indice_controle = 0;
        end
        temps_iteration=toc(temps_debut_iteration); % temps pour chaque iteration 

%% save data 
        vecteur_Poids = [vecteur_Poids;Poids];
        t_iteration = [t_iteration , temps_iteration];
        %N_Particles = [N_Particles,N];
        %iteration = [iteration , i]; 
        vecteur_Robot=[vecteur_Robot,[Robot.x;Robot.y;Robot.theta]];
        vecteur_particles=[vecteur_particles,[inf;inf;inf],[Particles.x;Particles.y;Particles.theta]];
    end
    
    
    
    T_fin=toc(T_Debut); % temps du programme  
    Data.desired_trajectory = PP;
    Data.vecteur_incertitude_x = vecteur_incertitude_x;
    Data.vecteur_incertitude_y = vecteur_incertitude_y;
    Data.vecteur_incertitude_theta = vecteur_incertitude_theta;
    Data.N_Particles = N_Particles;
    Data.t_iteration = t_iteration;
    Data.vecteur_Robot = vecteur_Robot;
    Data.vecteur_estimation = vecteur_estimation;
    Data.iteration = iteration;
    Data.T_convergence = T_convergence;
    Data.iteration_convergence = iteration_convergence;
    Data.vecteur_erreur = vecteur_erreur;
    Data.T_fin = T_fin;
    Data.vecteur_particles = vecteur_particles;
    Data.vecteur_Poids=vecteur_Poids;

  end



