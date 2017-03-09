classdef MarsCrimson < handle
    %MARSCRIMSON Interfaz a plataforma de ensayo de motores MarsCrimson.
    %  2015-2016 (C) Jose Atienza Piedra, Manuel Berenguel Soria
    %       2017 (C) Jose Luis Blanco Claraco 
    %  Universidad de Almeria
    % -------------------------------------------------------------------
        
    methods
        function [] = conectar(me, serialPortName)
            fprintf('[MarsCrimson] Abriendo puerto serie: %s...\n', serialPortName);
            me.m_serial = serial(serialPortName);
            fopen(me.m_serial);
            
            internal_set_cont_mode(me,0);
            pause(0.2);
            flushinput(me.m_serial);
        end
        
        function delete(me)
            fclose(me.m_serial);
            fprintf('[MarsCrimson] Cerrado.\n');
        end
        
        % Cambia el voltaje de actuación sobre el motor: volt entre -5 y +5
        % voltios, devolviendo el valor actual de velocidad (en voltios, -5 a +5).
        function [out_volt, timestamp] = escribir_voltaje_y_leer(me, volt)
            internal_set_DACs(me, volt, me.h('0x00'));
            %flushinput(me.m_serial); % Make sure we dont read old values
            [out_volt, timestamp_ms] = internal_read_ADC(me);
            timestamp = timestamp_ms*1e-3;
        end
        
        % Cambia el voltaje de actuación sobre el motor: volt entre -5 y +5
        % voltios, SIN devolver el valor actual de velocidad.
        function [] = escribir_voltaje(me, volt)
            internal_set_DACs(me, volt, me.h('0x01'));
        end
        
        % Lee la velocidad actual del motor (en voltios, -5 a +5). 
        % Llamar sólo tras activar el modo de medición continua.
        % Vea también: iniciar_medicion_continua(), parar_medicion_continua()
        function [out_volt, timestamp] = leer_velocidad(me)
            [out_volt, timestamp_ms] = internal_read_ADC(me);
            timestamp = timestamp_ms*1e-3;
        end

        % Habilita la lectura de velocidad del motor mediante la función
        % leer_velocidad()
        % Vea también: parar_medicion_continua(), leer_velocidad()        
        function [] = iniciar_medicion_continua(me, periodo_ms)
            me.internal_set_cont_mode(periodo_ms);
        end

        % Para la medición continua. 
        % Vea también: iniciar_medicion_continua(), leer_velocidad()
        function [] = parar_medicion_continua(me)
            me.internal_set_cont_mode(0);
        end
        
    end
    
    properties(Access=private)
        m_serial;
    end
    
    methods(Static, Access=private)
        function [ num ] = h( str )
            %H Convert a string hexadecimal number like '0x10' or '0x1A9F' to number
            num=sscanf(str,'%x');
        end        
        function [ out ] = makeword( BYTEH, BYTEL )
        %MAKEWORD Builds a 16bit word from 2 bytes (as numbers)
        out = bitor(...
            bitshift(uint16(BYTEH),8),...
            uint16(BYTEL)...
            );
        end        
        function [ out ] = makedword( WORDH, WORDL )
        %MAKEDWORD Builds a 32bit word from 2 words (as numbers)
        out = bitor(...
            bitshift(uint32(WORDH),16),...
            uint32(WORDL)...
            );
        end        
        function [ out ] = lobyte( word_value )
            %LOBYTE Extracts the lower 8-bit
            out = uint8( bitand( uint16(255), uint16(word_value) ) );
        end        
        function [ out ] = hibyte( word_value )
            %HIBYTE Extracts the upper 8-bit
            out = uint8(bitshift(uint16(word_value),-8));
        end        
    end
    
    methods(Access=private)
        function [] = internal_set_DACs(me, volt, msg_type)
            % Saturate:
            if (volt>5),
                volt = 5;
            elseif (volt<-5),
                volt=-5;
            end
            
            % Scale to 3V:
            volt = volt * 3.0/5.0;
            
            % Convert to pos/neg 2 DAC values:
            if (volt>=0)
                dac0 = volt;
                dac1 = 0;
            else 
                dac0 = 0;
                dac1 = -volt;
            end
            
            % Convert to uint16_t: XX/4096 * 3.3V 
            dac0_int = uint16( dac0 * 4096 / 3.3 );
            dac1_int = uint16( dac1 * 4096 / 3.3 );
            
            buf = uint8(zeros(1,7));
            buf(1) = me.h('0x69');  % header
            buf(2) = msg_type;  % type
            buf(3) = me.lobyte(dac0_int);
            buf(4) = me.hibyte(dac0_int);
            buf(5) = me.lobyte(dac1_int);
            buf(6) = me.hibyte(dac1_int);
            buf(7) = me.h('0x96');  % header
            
            fwrite(me.m_serial, buf);
        end

        function [] = internal_set_cont_mode(me, period_ms)
            buf = uint8(zeros(1,4));
            buf(1) = me.h('0x69');  % header
            buf(2) = 2;  % type
            buf(3) = uint8(period_ms);
            buf(4) = me.h('0x96');  % header
            
            fwrite(me.m_serial, buf);
        end
        
        function [out_volt, timestamp_ms] = internal_read_ADC(me)
            buf = fread(me.m_serial, 11);
            if (length(buf)~=11)
                error('[MarsCrimson] No se pudieron leer datos desde la placa de motores.');
            end
            if (buf(1)~=105 || buf(11)~=150) % 0x69, 0x96
                error('[MarsCrimson] Error de sincronía de trama en comunicación con placa de motores.');
            end
            adc0 = double( me.makeword(buf(8),buf(7)) );
            adc1 = double( me.makeword(buf(10),buf(9)) );
            timestamp_ms = double(me.makedword(me.makeword(buf(6),buf(5)),me.makeword(buf(4),buf(3)) ));
            
            if (adc0>adc1)
                out_volt = adc0 * 5.0/4095;
            else
                out_volt = -(adc1 * 5.0/4095);
            end
        end
        
    end
    
    
end

